-- SIGE — frequency and final academic result commands
-- Builds higher-level results only from already published source results.

create or replace function public.calculate_frequency_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_first_trimester_result_id uuid,
  p_second_trimester_result_id uuid,
  p_third_trimester_result_id uuid,
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
  values_count integer;
  mfd numeric(8,4);
  snapshot jsonb;
  old_result_id uuid;
  result_id uuid;
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
  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if not exists (
    select 1
    from public.academic_results ar
    where ar.id in (
      p_first_trimester_result_id,
      p_second_trimester_result_id,
      p_third_trimester_result_id
    )
    group by ar.student_id, ar.course_offering_id, ar.academic_year_id
    having count(*) = 3
       and bool_and(ar.student_id = p_student_id)
       and bool_and(ar.course_offering_id = p_course_offering_id)
       and bool_and(ar.academic_year_id = academic_year_id)
       and bool_and(ar.result_type = 'TRIMESTER')
       and bool_and(ar.status = 'PUBLISHED')
       and count(distinct ar.assessment_period_id) = 3
  ) then
    raise exception 'THREE_PUBLISHED_TRIMESTER_RESULTS_REQUIRED';
  end if;

  command_state := private.begin_command(
    'calculate_frequency_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  select count(*), avg(ar.value)
    into values_count, mfd
  from public.academic_results ar
  where ar.id in (
    p_first_trimester_result_id,
    p_second_trimester_result_id,
    p_third_trimester_result_id
  )
    and ar.status = 'PUBLISHED'
    and ar.result_type = 'TRIMESTER';

  if values_count <> 3 or mfd is null then
    raise exception 'FREQUENCY_RESULT_INCOMPLETE';
  end if;

  snapshot := jsonb_build_object(
    'rule_version', 'MZ-ES-2022-06-30',
    'source_results', jsonb_build_array(
      p_first_trimester_result_id,
      p_second_trimester_result_id,
      p_third_trimester_result_id
    ),
    'values', (
      select jsonb_agg(ar.value order by ar.calculated_at)
      from public.academic_results ar
      where ar.id in (
        p_first_trimester_result_id,
        p_second_trimester_result_id,
        p_third_trimester_result_id
      )
    ),
    'mfd', mfd
  );

  if exists (select 1 from public.academic_results where student_id = p_student_id and course_offering_id = p_course_offering_id and result_type = 'FREQUENCY' and status = 'PUBLISHED') then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION';
  end if;

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and result_type = 'FREQUENCY'
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
    result_type, status, rule_version, value, display_value,
    classification, input_snapshot, calculated_by, supersedes_result_id
  )
  values (
    school_id, academic_year_id, p_student_id, p_course_offering_id,
    'FREQUENCY', 'CALCULATED', 'MZ-ES-2022-06-30',
    mfd, round(mfd),
    case
      when round(mfd) >= 19 then 'EXCELENTE'
      when round(mfd) >= 17 then 'MUITO_BOM'
      when round(mfd) >= 14 then 'BOM'
      when round(mfd) >= 10 then 'SUFICIENTE'
      else 'NAO_SUFICIENTE'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_FREQUENCY_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'FREQUENCY',
    'status', 'CALCULATED',
    'value', mfd,
    'display_value', round(mfd),
    'rule_version', 'MZ-ES-2022-06-30'
  );

  perform private.complete_command(
    'calculate_frequency_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text) to authenticated;


create or replace function public.calculate_final_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_frequency_result_id uuid,
  p_exam_assessment_result_id uuid,
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
  nd numeric(8,4);
  ne numeric(8,4);
  nf numeric(8,4);
  exam_assessment_id uuid;
  exam_type public.assessment_type;
  exam_status public.assessment_result_status;
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
  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  select ar.value
    into nd
  from public.academic_results ar
  where ar.id = p_frequency_result_id
    and ar.student_id = p_student_id
    and ar.course_offering_id = p_course_offering_id
    and ar.academic_year_id = academic_year_id
    and ar.result_type = 'FREQUENCY'
    and ar.status = 'PUBLISHED';

  if nd is null then raise exception 'PUBLISHED_FREQUENCY_RESULT_REQUIRED'; end if;

  select ar.assessment_id, ar.normalized_score, a.type, ar.status
    into exam_assessment_id, ne, exam_type, exam_status
  from public.assessment_results ar
  join public.assessments a on a.id = ar.assessment_id
  where ar.id = p_exam_assessment_result_id
    and ar.student_id = p_student_id
    and a.course_offering_id = p_course_offering_id;

  if exam_assessment_id is null then raise exception 'EXAM_RESULT_NOT_FOUND'; end if;
  if exam_type <> 'EXAM' then raise exception 'ASSESSMENT_RESULT_IS_NOT_EXAM'; end if;
  if exam_status <> 'PUBLISHED' then raise exception 'PUBLISHED_EXAM_RESULT_REQUIRED'; end if;
  if ne is null then raise exception 'EXAM_SCORE_REQUIRED'; end if;

  command_state := private.begin_command(
    'calculate_final_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  nf := (2 * nd + ne) / 3;

  snapshot := jsonb_build_object(
    'rule_version', 'MZ-ES-2022-06-30',
    'frequency_result_id', p_frequency_result_id,
    'exam_assessment_result_id', p_exam_assessment_result_id,
    'nd', nd,
    'ne', ne,
    'nf', nf
  );

  if exists (select 1 from public.academic_results where student_id = p_student_id and course_offering_id = p_course_offering_id and result_type = 'FINAL' and status = 'PUBLISHED') then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION';
  end if;

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and result_type = 'FINAL'
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
    result_type, status, rule_version, value, display_value,
    classification, input_snapshot, calculated_by, supersedes_result_id
  )
  values (
    school_id, academic_year_id, p_student_id, p_course_offering_id,
    'FINAL', 'CALCULATED', 'MZ-ES-2022-06-30',
    nf, round(nf),
    case
      when round(nf) >= 19 then 'EXCELENTE'
      when round(nf) >= 17 then 'MUITO_BOM'
      when round(nf) >= 14 then 'BOM'
      when round(nf) >= 10 then 'SUFICIENTE'
      else 'NAO_SUFICIENTE'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_FINAL_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'FINAL',
    'status', 'CALCULATED',
    'value', nf,
    'display_value', round(nf),
    'rule_version', 'MZ-ES-2022-06-30'
  );

  perform private.complete_command(
    'calculate_final_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) to authenticated;
