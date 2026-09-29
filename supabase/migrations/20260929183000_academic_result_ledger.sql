-- SIGE — academic result ledger
-- Derived academic results are persisted as versioned snapshots.
-- Source assessment events remain immutable history; recalculation creates
-- a new result version instead of silently rewriting an official result.

create type public.academic_result_type as enum (
  'TRIMESTER',
  'FREQUENCY',
  'DISCIPLINE',
  'FINAL',
  'RECOVERY'
);

create type public.academic_result_status as enum (
  'CALCULATED',
  'HOMOLOGATED',
  'PUBLISHED',
  'SUPERSEDED'
);

create table public.academic_results (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  academic_year_id uuid not null references public.academic_years(id),
  student_id uuid not null references public.students(id),
  course_offering_id uuid not null references public.course_offerings(id),
  assessment_period_id uuid references public.assessment_periods(id),
  result_type public.academic_result_type not null,
  status public.academic_result_status not null default 'CALCULATED',
  rule_version text not null,
  value numeric(8,4),
  display_value numeric(5,2),
  classification text,
  input_snapshot jsonb not null,
  calculated_at timestamptz not null default now(),
  calculated_by uuid references auth.users(id),
  homologated_at timestamptz,
  homologated_by uuid references auth.users(id),
  published_at timestamptz,
  published_by uuid references auth.users(id),
  supersedes_result_id uuid references public.academic_results(id),
  created_at timestamptz not null default now(),
  constraint academic_results_snapshot_object
    check (jsonb_typeof(input_snapshot) = 'object'),
  constraint academic_results_value_range
    check (value is null or (value >= 0 and value <= 20)),
  constraint academic_results_display_range
    check (display_value is null or (display_value >= 0 and display_value <= 20)),
  constraint academic_results_status_timestamps
    check (
      (status <> 'HOMOLOGATED' or homologated_at is not null)
      and (status <> 'PUBLISHED' or published_at is not null)
    )
);

create index academic_results_lookup
  on public.academic_results (
    school_id, academic_year_id, student_id, course_offering_id
  );

create index academic_results_period
  on public.academic_results (
    assessment_period_id, course_offering_id, result_type, status
  );

alter table public.academic_results enable row level security;

create policy academic_results_select
  on public.academic_results
  for select to authenticated
  using (
    private.has_permission('assessment.read', school_id)
    or private.has_permission('assessment.manage', school_id)
  );

revoke insert, update, delete on public.academic_results from authenticated;
grant select on public.academic_results to authenticated;


create or replace function public.calculate_trimester_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_assessment_period_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  academic_year_id uuid;
  period_year uuid;
  participant boolean;
  acs_count integer;
  at_count integer;
  macs numeric(8,4);
  at_value numeric(8,4);
  mt numeric(8,4);
  result_id uuid;
  old_result_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id
    into school_id, academic_year_id
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ap.academic_year_id
    into period_year
  from public.assessment_periods ap
  where ap.id = p_assessment_period_id
  for share;

  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if period_year <> academic_year_id then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;

  if not (
    (select private.has_permission('assessment.manage', school_id))
    or (select private.has_permission('assessment.manage', school_id))
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select exists (
    select 1
    from public.student_course_participations scp
    where scp.student_id = p_student_id
      and scp.course_offering_id = p_course_offering_id
      and scp.status = 'ACTIVE'
  ) into participant;

  if not participant then raise exception 'STUDENT_NOT_COURSE_PARTICIPANT'; end if;

  command_state := private.begin_command(
    'calculate_trimester_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  select count(*) filter (
           where a.type = 'ACS'
             and ar.status = 'ENTERED'
             and ar.normalized_score is not null
         ),
         avg(ar.normalized_score) filter (
           where a.type = 'ACS'
             and ar.status = 'ENTERED'
             and ar.normalized_score is not null
         ),
         count(*) filter (
           where a.type = 'AT'
             and ar.status = 'ENTERED'
             and ar.normalized_score is not null
         ),
         max(ar.normalized_score) filter (
           where a.type = 'AT'
             and ar.status = 'ENTERED'
             and ar.normalized_score is not null
         )
    into acs_count, macs, at_count, at_value
  from public.assessments a
  join public.assessment_results ar on ar.assessment_id = a.id
  where a.course_offering_id = p_course_offering_id
    and a.assessment_period_id = p_assessment_period_id
    and ar.student_id = p_student_id;

  if acs_count < 2 or at_count <> 1 then
    raise exception 'TRIMESTER_RESULT_INCOMPLETE';
  end if;

  mt := (2 * macs + at_value) / 3;

  snapshot := jsonb_build_object(
    'rule_version', 'MZ-ES-2022-06-30',
    'assessment_period_id', p_assessment_period_id,
    'course_offering_id', p_course_offering_id,
    'student_id', p_student_id,
    'acs_count', acs_count,
    'macs', macs,
    'at', at_value,
    'mt', mt,
    'assessments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'assessment_id', a.id,
          'type', a.type,
          'title', a.title,
          'result_id', ar.id,
          'status', ar.status,
          'normalized_score', ar.normalized_score
        )
        order by a.assessment_date nulls last, a.created_at, a.id
      )
      from public.assessments a
      join public.assessment_results ar on ar.assessment_id = a.id
      where a.course_offering_id = p_course_offering_id
        and a.assessment_period_id = p_assessment_period_id
        and ar.student_id = p_student_id
    ), '[]'::jsonb)
  );

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and assessment_period_id = p_assessment_period_id
    and result_type = 'TRIMESTER'
    and status in ('CALCULATED','HOMOLOGATED')
  order by calculated_at desc
  limit 1
  for update;

  if old_result_id is not null then
    update public.academic_results
       set status = 'SUPERSEDED'
     where id = old_result_id;
  end if;

  insert into public.academic_results (
    school_id, academic_year_id, student_id, course_offering_id,
    assessment_period_id, result_type, status, rule_version,
    value, display_value, classification, input_snapshot, calculated_by, supersedes_result_id
  )
  values (
    school_id, academic_year_id, p_student_id, p_course_offering_id,
    p_assessment_period_id, 'TRIMESTER', 'CALCULATED',
    'MZ-ES-2022-06-30', mt, round(mt), 
    case
      when round(mt) >= 19 then 'EXCELENTE'
      when round(mt) >= 17 then 'MUITO_BOM'
      when round(mt) >= 14 then 'BOM'
      when round(mt) >= 10 then 'SUFICIENTE'
      else 'NAO_SUFICIENTE'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_TRIMESTER_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'TRIMESTER',
    'status', 'CALCULATED',
    'value', mt,
    'display_value', round(mt),
    'rule_version', 'MZ-ES-2022-06-30'
  );

  perform private.complete_command(
    'calculate_trimester_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) to authenticated;


create or replace function public.homologate_academic_result(
  p_academic_result_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  current_status public.academic_result_status;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ar.school_id, ar.status
    into school_id, current_status
  from public.academic_results ar
  where ar.id = p_academic_result_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_RESULT_NOT_FOUND'; end if;
  if current_status <> 'CALCULATED' then raise exception 'RESULT_NOT_CALCULATED'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'homologate_academic_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.academic_results
     set status = 'HOMOLOGATED',
         homologated_at = now(),
         homologated_by = actor
   where id = p_academic_result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id
  )
  values (
    school_id, actor, 'HOMOLOGATE_ACADEMIC_RESULT',
    'academic_result', p_academic_result_id
  );

  result := jsonb_build_object(
    'academic_result_id', p_academic_result_id,
    'status', 'HOMOLOGATED'
  );

  perform private.complete_command(
    'homologate_academic_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.homologate_academic_result(uuid,text,text) from public;
grant execute on function public.homologate_academic_result(uuid,text,text) to authenticated;


create or replace function public.publish_academic_result(
  p_academic_result_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  current_status public.academic_result_status;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ar.school_id, ar.status
    into school_id, current_status
  from public.academic_results ar
  where ar.id = p_academic_result_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_RESULT_NOT_FOUND'; end if;
  if current_status <> 'HOMOLOGATED' then raise exception 'RESULT_NOT_HOMOLOGATED'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'publish_academic_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.academic_results
     set status = 'PUBLISHED',
         published_at = now(),
         published_by = actor
   where id = p_academic_result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id
  )
  values (
    school_id, actor, 'PUBLISH_ACADEMIC_RESULT',
    'academic_result', p_academic_result_id
  );

  result := jsonb_build_object(
    'academic_result_id', p_academic_result_id,
    'status', 'PUBLISHED'
  );

  perform private.complete_command(
    'publish_academic_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.publish_academic_result(uuid,text,text) from public;
grant execute on function public.publish_academic_result(uuid,text,text) to authenticated;
