-- SIGE 0019 — Transactional assessment commands
--
-- Assessment lifecycle:
--   create -> OPEN -> results entered -> PUBLISHED
-- Published results are immutable through the generic Data API and can only
-- be changed by a dedicated correction command added in the next hardening
-- migration.

create or replace function public.create_assessment(
  p_course_offering_id uuid,
  p_assessment_period_id uuid,
  p_type public.assessment_type,
  p_title text,
  p_assessment_date date default null,
  p_max_score numeric(8,4) default 20,
  p_weight numeric(8,4) default null,
  p_idempotency_key text default null,
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
  offering_year uuid;
  offering_status public.course_offering_status;
  period_year uuid;
  period_active boolean;
  assessment_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_title is null or length(trim(p_title)) < 2 then raise exception 'INVALID_ASSESSMENT_TITLE'; end if;
  if p_max_score <= 0 then raise exception 'INVALID_MAX_SCORE'; end if;
  if p_weight is not null and p_weight < 0 then raise exception 'INVALID_WEIGHT'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id, co.status
    into school_id, offering_year, offering_status
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  if offering_status not in ('OPEN','ACTIVE') then raise exception 'COURSE_OFFERING_NOT_OPEN'; end if;

  select ap.academic_year_id, ap.active
    into period_year, period_active
  from public.assessment_periods ap
  where ap.id = p_assessment_period_id
  for share;

  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if not period_active then raise exception 'ASSESSMENT_PERIOD_INACTIVE'; end if;
  if offering_year <> period_year then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;

  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command('create_assessment', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  insert into public.assessments (
    course_offering_id, assessment_period_id, type, title,
    assessment_date, max_score, weight, status, created_by
  )
  values (
    p_course_offering_id, p_assessment_period_id, p_type, trim(p_title),
    p_assessment_date, p_max_score, p_weight, 'OPEN', actor
  )
  returning id into assessment_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CREATE_ASSESSMENT', 'assessment', assessment_id,
    jsonb_build_object(
      'course_offering_id', p_course_offering_id,
      'assessment_period_id', p_assessment_period_id,
      'type', p_type,
      'title', p_title,
      'max_score', p_max_score,
      'weight', p_weight
    )
  );

  result := jsonb_build_object(
    'assessment_id', assessment_id,
    'status', 'OPEN',
    'max_score', p_max_score
  );

  perform private.complete_command('create_assessment', school_id, p_idempotency_key, result);
  return result;
end;
$$;

create or replace function public.save_assessment_result(
  p_assessment_id uuid,
  p_student_id uuid,
  p_raw_score numeric(8,4),
  p_status public.assessment_result_status default 'ENTERED',
  p_comment text default null,
  p_idempotency_key text default null,
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
  offering_id uuid;
  assessment_status_value public.assessment_status;
  max_score numeric(8,4);
  current_result_id uuid;
  current_result_status public.assessment_result_status;
  normalized numeric(8,4);
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, a.course_offering_id, a.status, a.max_score
    into school_id, offering_id, assessment_status_value, max_score
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where a.id = p_assessment_id
  for share;

  if school_id is null then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if assessment_status_value <> 'OPEN' then raise exception 'ASSESSMENT_NOT_EDITABLE'; end if;

  if p_status = 'ENTERED' then
    if p_raw_score is null or p_raw_score < 0 or p_raw_score > max_score then
      raise exception 'INVALID_SCORE';
    end if;
    normalized := (p_raw_score / max_score) * 20;
  elsif p_status in ('ABSENT','EXCUSED') then
    normalized := null;
  else
    raise exception 'INVALID_ENTRY_STATUS';
  end if;

  if not (
    (select private.has_permission('assessment.manage', school_id))
    or (
      (select private.has_permission('assessment.own.enter', school_id))
      and exists (
        select 1
        from public.teacher_assignments ta
        join public.teachers t on t.id = ta.teacher_id
        where ta.course_offering_id = offering_id
          and t.person_id = (select private.current_person_id())
          and ta.active
          and ta.starts_on <= current_date
          and (ta.ends_on is null or ta.ends_on >= current_date)
      )
    )
  ) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command('save_assessment_result', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  select ar.id, ar.status
    into current_result_id, current_result_status
  from public.assessment_results ar
  where ar.assessment_id = p_assessment_id
    and ar.student_id = p_student_id
  for update;

  if current_result_status = 'PUBLISHED' then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION_COMMAND';
  end if;

  if current_result_id is null then
    insert into public.assessment_results (
      assessment_id, student_id, raw_score, normalized_score,
      status, comment, entered_by, entered_at
    )
    values (
      p_assessment_id, p_student_id, p_raw_score, normalized,
      p_status, p_comment, actor, now()
    )
    returning id into current_result_id;
  else
    update public.assessment_results
       set raw_score = p_raw_score,
           normalized_score = normalized,
           status = p_status,
           comment = p_comment,
           entered_by = actor,
           entered_at = now()
     where id = current_result_id;
  end if;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'SAVE_ASSESSMENT_RESULT', 'assessment_result', current_result_id,
    jsonb_build_object(
      'assessment_id', p_assessment_id,
      'student_id', p_student_id,
      'raw_score', p_raw_score,
      'normalized_score', normalized,
      'status', p_status
    )
  );

  result := jsonb_build_object(
    'assessment_result_id', current_result_id,
    'status', p_status,
    'normalized_score', normalized
  );

  perform private.complete_command('save_assessment_result', school_id, p_idempotency_key, result);
  return result;
end;
$$;

create or replace function public.publish_assessment(
  p_assessment_id uuid,
  p_idempotency_key text default null,
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
  offering_id uuid;
  assessment_status_value public.assessment_status;
  participants_count integer;
  results_count integer;
  missing_count integer;
  published_at timestamptz;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, a.course_offering_id, a.status
    into school_id, offering_id, assessment_status_value
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where a.id = p_assessment_id
  for update;

  if school_id is null then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then raise exception 'FORBIDDEN'; end if;

  command_state := private.begin_command('publish_assessment', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  if assessment_status_value <> 'OPEN' then
    raise exception 'ASSESSMENT_NOT_OPEN';
  end if;

  select count(*)
    into participants_count
  from public.student_course_participations scp
  join public.assessments a on a.id = p_assessment_id
  where scp.course_offering_id = offering_id
    and scp.status = 'ACTIVE'
    and (a.assessment_date is null or scp.starts_on <= a.assessment_date)
    and (scp.ends_on is null or a.assessment_date is null or scp.ends_on >= a.assessment_date);

  select count(*)
    into results_count
  from public.assessment_results ar
  where ar.assessment_id = p_assessment_id;

  select count(*)
    into missing_count
  from public.student_course_participations scp
  join public.assessments a on a.id = p_assessment_id
  left join public.assessment_results ar
    on ar.student_id = scp.student_id
   and ar.assessment_id = p_assessment_id
  where scp.course_offering_id = offering_id
    and scp.status = 'ACTIVE'
    and (a.assessment_date is null or scp.starts_on <= a.assessment_date)
    and (scp.ends_on is null or a.assessment_date is null or scp.ends_on >= a.assessment_date)
    and (ar.id is null or ar.status = 'MISSING');

  if participants_count = 0 then raise exception 'ASSESSMENT_HAS_NO_PARTICIPANTS'; end if;
  if missing_count > 0 or results_count < participants_count then
    raise exception 'ASSESSMENT_RESULTS_INCOMPLETE';
  end if;

  published_at := now();

  update public.assessment_results
     set status = 'PUBLISHED',
         published_at = published_at,
         published_by = actor
   where assessment_id = p_assessment_id
     and status <> 'PUBLISHED';

  update public.assessments
     set status = 'PUBLISHED',
         published_at = published_at,
         published_by = actor
   where id = p_assessment_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'PUBLISH_ASSESSMENT', 'assessment', p_assessment_id,
    jsonb_build_object(
      'offering_id', offering_id,
      'published_at', published_at,
      'participants_count', participants_count
    )
  );

  result := jsonb_build_object(
    'assessment_id', p_assessment_id,
    'status', 'PUBLISHED',
    'published_at', published_at,
    'participants_count', participants_count
  );

  perform private.complete_command('publish_assessment', school_id, p_idempotency_key, result);
  return result;
end;
$$;

revoke all on function public.create_assessment(uuid,uuid,public.assessment_type,text,date,numeric,numeric,text,text) from public;
revoke all on function public.save_assessment_result(uuid,uuid,numeric,public.assessment_result_status,text,text,text) from public;
revoke all on function public.publish_assessment(uuid,text,text) from public;

grant execute on function public.create_assessment(uuid,uuid,public.assessment_type,text,date,numeric,numeric,text,text) to authenticated;
grant execute on function public.save_assessment_result(uuid,uuid,numeric,public.assessment_result_status,text,text,text) to authenticated;
grant execute on function public.publish_assessment(uuid,text,text) to authenticated;

revoke insert, update, delete on public.assessments from authenticated;
revoke insert, update, delete on public.assessment_results from authenticated;
grant select on public.assessments to authenticated;
grant select on public.assessment_results to authenticated;


create or replace function public.correct_published_result(
  p_assessment_result_id uuid,
  p_raw_score numeric(8,4),
  p_status public.assessment_result_status default 'PUBLISHED',
  p_comment text default null,
  p_reason text default null,
  p_idempotency_key text default null,
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
  assessment_id uuid;
  max_score numeric(8,4);
  current_status public.assessment_result_status;
  normalized numeric(8,4);
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'CORRECTION_REASON_REQUIRED';
  end if;

  select co.school_id, ar.assessment_id, a.max_score, ar.status
    into school_id, assessment_id, max_score, current_status
  from public.assessment_results ar
  join public.assessments a on a.id = ar.assessment_id
  join public.course_offerings co on co.id = a.course_offering_id
  where ar.id = p_assessment_result_id
  for update;

  if school_id is null then raise exception 'ASSESSMENT_RESULT_NOT_FOUND'; end if;
  if current_status <> 'PUBLISHED' then raise exception 'RESULT_IS_NOT_PUBLISHED'; end if;
  if p_status <> 'PUBLISHED' then raise exception 'CORRECTION_MUST_REMAIN_PUBLISHED'; end if;
  if p_raw_score is null or p_raw_score < 0 or p_raw_score > max_score then
    raise exception 'INVALID_SCORE';
  end if;

  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'correct_published_result',
    school_id,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  normalized := (p_raw_score / max_score) * 20;

  update public.assessment_results
     set raw_score = p_raw_score,
         normalized_score = normalized,
         status = 'PUBLISHED',
         comment = p_comment,
         entered_by = actor,
         entered_at = now(),
         published_at = now(),
         published_by = actor,
         correction_reason = trim(p_reason)
   where id = p_assessment_result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id,
    reason, after_data
  )
  values (
    school_id, actor, 'CORRECT_PUBLISHED_RESULT', 'assessment_result',
    p_assessment_result_id, trim(p_reason),
    jsonb_build_object(
      'assessment_id', assessment_id,
      'raw_score', p_raw_score,
      'normalized_score', normalized,
      'status', 'PUBLISHED'
    )
  );

  result := jsonb_build_object(
    'assessment_result_id', p_assessment_result_id,
    'status', 'PUBLISHED',
    'normalized_score', normalized
  );

  perform private.complete_command(
    'correct_published_result',
    school_id,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

revoke all on function public.correct_published_result(uuid,numeric,public.assessment_result_status,text,text,text,text) from public;
grant execute on function public.correct_published_result(uuid,numeric,public.assessment_result_status,text,text,text,text) to authenticated;
