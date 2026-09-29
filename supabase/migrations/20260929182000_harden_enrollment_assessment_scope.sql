-- SIGE — harden enrollment exits and assessment participant scope
--
-- This migration closes two domain gaps:
-- 1. Enrollment exits are explicit commands; history is never deleted.
-- 2. Assessment results can only exist for students who are active participants
--    in the offering at the assessment date.

create or replace function public.withdraw_student(
  p_enrollment_id uuid,
  p_withdrawn_on date,
  p_reason text,
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
  enrollment_status public.enrollment_status;
  enrolled_on date;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'WITHDRAWAL_REASON_REQUIRED';
  end if;

  select s.school_id, e.status, e.enrolled_on
    into school_id, enrollment_status, enrolled_on
  from public.student_enrollments e
  join public.students s on s.id = e.student_id
  where e.id = p_enrollment_id
  for update;

  if school_id is null then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
  if not (select private.has_permission('enrollment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if enrollment_status not in ('ACTIVE','TRANSFERRED_IN') then
    raise exception 'ENROLLMENT_NOT_ACTIVE';
  end if;
  if p_withdrawn_on < enrolled_on then
    raise exception 'INVALID_EXIT_DATE';
  end if;

  command_state := private.begin_command(
    'withdraw_student', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.student_enrollments
     set status = 'WITHDRAWN',
         exited_on = p_withdrawn_on,
         exit_reason = trim(p_reason)
   where id = p_enrollment_id;

  update public.class_placements
     set status = 'ENDED',
         ends_on = p_withdrawn_on
   where enrollment_id = p_enrollment_id
     and status = 'ACTIVE'
     and starts_on <= p_withdrawn_on
     and (ends_on is null or ends_on > p_withdrawn_on);

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id,
    reason, after_data
  )
  values (
    school_id, actor, 'WITHDRAW_STUDENT', 'student_enrollment', p_enrollment_id,
    trim(p_reason),
    jsonb_build_object(
      'status', 'WITHDRAWN',
      'exited_on', p_withdrawn_on,
      'exit_reason', trim(p_reason)
    )
  );

  result := jsonb_build_object(
    'enrollment_id', p_enrollment_id,
    'status', 'WITHDRAWN',
    'exited_on', p_withdrawn_on
  );

  perform private.complete_command(
    'withdraw_student', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

create or replace function public.transfer_student_out(
  p_enrollment_id uuid,
  p_transfer_on date,
  p_destination text,
  p_reason text,
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
  enrollment_status public.enrollment_status;
  enrolled_on date;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_destination is null or length(trim(p_destination)) < 2 then
    raise exception 'TRANSFER_DESTINATION_REQUIRED';
  end if;
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'TRANSFER_REASON_REQUIRED';
  end if;

  select s.school_id, e.status, e.enrolled_on
    into school_id, enrollment_status, enrolled_on
  from public.student_enrollments e
  join public.students s on s.id = e.student_id
  where e.id = p_enrollment_id
  for update;

  if school_id is null then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
  if not (select private.has_permission('enrollment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if enrollment_status not in ('ACTIVE','TRANSFERRED_IN') then
    raise exception 'ENROLLMENT_NOT_ACTIVE';
  end if;
  if p_transfer_on < enrolled_on then
    raise exception 'INVALID_EXIT_DATE';
  end if;

  command_state := private.begin_command(
    'transfer_student_out', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.student_enrollments
     set status = 'TRANSFERRED_OUT',
         exited_on = p_transfer_on,
         exit_reason = trim(p_reason)
   where id = p_enrollment_id;

  update public.class_placements
     set status = 'ENDED',
         ends_on = p_transfer_on
   where enrollment_id = p_enrollment_id
     and status = 'ACTIVE'
     and starts_on <= p_transfer_on
     and (ends_on is null or ends_on > p_transfer_on);

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id,
    reason, after_data
  )
  values (
    school_id, actor, 'TRANSFER_STUDENT_OUT', 'student_enrollment', p_enrollment_id,
    trim(p_reason),
    jsonb_build_object(
      'status', 'TRANSFERRED_OUT',
      'exited_on', p_transfer_on,
      'destination', trim(p_destination),
      'reason', trim(p_reason)
    )
  );

  result := jsonb_build_object(
    'enrollment_id', p_enrollment_id,
    'status', 'TRANSFERRED_OUT',
    'exited_on', p_transfer_on,
    'destination', trim(p_destination)
  );

  perform private.complete_command(
    'transfer_student_out', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

revoke all on function public.withdraw_student(uuid,date,text,text,text) from public;
revoke all on function public.transfer_student_out(uuid,date,text,text,text,text) from public;

grant execute on function public.withdraw_student(uuid,date,text,text,text) to authenticated;
grant execute on function public.transfer_student_out(uuid,date,text,text,text,text) to authenticated;


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
  assessment_date date;
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

  select co.school_id, a.course_offering_id, a.assessment_date,
         a.status, a.max_score
    into school_id, offering_id, assessment_date,
         assessment_status_value, max_score
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where a.id = p_assessment_id
  for share;

  if school_id is null then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if assessment_status_value <> 'OPEN' then raise exception 'ASSESSMENT_NOT_EDITABLE'; end if;

  if not exists (
    select 1
    from public.student_course_participations scp
    where scp.student_id = p_student_id
      and scp.course_offering_id = offering_id
      and scp.status = 'ACTIVE'
      and (assessment_date is null or scp.starts_on <= assessment_date)
      and (scp.ends_on is null or assessment_date is null or scp.ends_on >= assessment_date)
  ) then
    raise exception 'STUDENT_NOT_ASSESSMENT_PARTICIPANT';
  end if;

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
          and ta.starts_on <= coalesce(assessment_date, current_date)
          and (ta.ends_on is null or ta.ends_on >= coalesce(assessment_date, current_date))
      )
    )
  ) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'save_assessment_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

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

  perform private.complete_command(
    'save_assessment_result', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

revoke all on function public.save_assessment_result(uuid,uuid,numeric,public.assessment_result_status,text,text,text) from public;
grant execute on function public.save_assessment_result(uuid,uuid,numeric,public.assessment_result_status,text,text,text) to authenticated;


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
  assessment_date date;
  assessment_status_value public.assessment_status;
  participants_count integer;
  results_count integer;
  missing_count integer;
  foreign_results_count integer;
  published_at timestamptz;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, a.course_offering_id, a.assessment_date, a.status
    into school_id, offering_id, assessment_date, assessment_status_value
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where a.id = p_assessment_id
  for update;

  if school_id is null then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then raise exception 'FORBIDDEN'; end if;

  command_state := private.begin_command(
    'publish_assessment', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  if assessment_status_value <> 'OPEN' then
    raise exception 'ASSESSMENT_NOT_OPEN';
  end if;

  select count(*)
    into participants_count
  from public.student_course_participations scp
  where scp.course_offering_id = offering_id
    and scp.status = 'ACTIVE'
    and (assessment_date is null or scp.starts_on <= assessment_date)
    and (scp.ends_on is null or assessment_date is null or scp.ends_on >= assessment_date);

  select count(*)
    into results_count
  from public.assessment_results ar
  where ar.assessment_id = p_assessment_id;

  select count(*)
    into foreign_results_count
  from public.assessment_results ar
  where ar.assessment_id = p_assessment_id
    and not exists (
      select 1
      from public.student_course_participations scp
      where scp.student_id = ar.student_id
        and scp.course_offering_id = offering_id
        and scp.status = 'ACTIVE'
        and (assessment_date is null or scp.starts_on <= assessment_date)
        and (scp.ends_on is null or assessment_date is null or scp.ends_on >= assessment_date)
    );

  select count(*)
    into missing_count
  from public.student_course_participations scp
  where scp.course_offering_id = offering_id
    and scp.status = 'ACTIVE'
    and (assessment_date is null or scp.starts_on <= assessment_date)
    and (scp.ends_on is null or assessment_date is null or scp.ends_on >= assessment_date)
    and not exists (
      select 1
      from public.assessment_results ar
      where ar.student_id = scp.student_id
        and ar.assessment_id = p_assessment_id
        and ar.status in ('ENTERED','ABSENT','EXCUSED','PUBLISHED')
    );

  if participants_count = 0 then raise exception 'ASSESSMENT_HAS_NO_PARTICIPANTS'; end if;
  if foreign_results_count > 0 then raise exception 'ASSESSMENT_HAS_OUT_OF_SCOPE_RESULTS'; end if;
  if missing_count > 0 or results_count <> participants_count then
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

  perform private.complete_command(
    'publish_assessment', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

revoke all on function public.publish_assessment(uuid,text,text) from public;
grant execute on function public.publish_assessment(uuid,text,text) to authenticated;
