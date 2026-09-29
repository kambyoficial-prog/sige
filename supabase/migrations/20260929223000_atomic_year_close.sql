-- SIGE 0035 — atomic operational finalization during year close

create or replace function public.close_academic_year(
  p_academic_year_id uuid,
  p_close_on date default current_date,
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
  year_status public.academic_year_status;
  year_start date;
  year_end date;
  open_assessments integer;
  pending_enrollments integer;
  active_enrollments integer;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status, ay.starts_on, ay.ends_on
    into school_id, year_status, year_start, year_end
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if not (select private.has_permission('academic_year.close', school_id)) then raise exception 'FORBIDDEN'; end if;

  command_state := private.begin_command('close_academic_year', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  if year_status <> 'OPEN' then raise exception 'ACADEMIC_YEAR_NOT_OPEN'; end if;
  if p_close_on < year_start or p_close_on > year_end then
    raise exception 'INVALID_CLOSE_DATE';
  end if;

  if p_close_on < year_end and (p_reason is null or length(trim(p_reason)) < 5) then
    raise exception 'EARLY_CLOSE_REQUIRES_REASON';
  end if;

  select count(*)
    into open_assessments
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where co.academic_year_id = p_academic_year_id
    and a.status = 'OPEN';

  if open_assessments > 0 then
    raise exception 'OPEN_ASSESSMENTS_REMAIN';
  end if;

  if exists (
    select 1
    from public.assessment_periods ap
    where ap.academic_year_id = p_academic_year_id
      and ap.active
      and ap.status <> 'CLOSED'
  ) then
    raise exception 'OPEN_ASSESSMENT_PERIODS_REMAIN';
  end if;

  select count(*)
    into pending_enrollments
  from public.student_enrollments e
  where e.academic_year_id = p_academic_year_id
    and e.status = 'PENDING';

  if pending_enrollments > 0 then
    raise exception 'PENDING_ENROLLMENTS_REMAIN';
  end if;

  select count(*)
    into active_enrollments
  from public.student_enrollments e
  where e.academic_year_id = p_academic_year_id
    and e.status in ('ACTIVE','TRANSFERRED_IN');

  update public.student_enrollments
     set status = 'COMPLETED',
         exited_on = p_close_on,
         exit_reason = coalesce(nullif(trim(p_reason), ''), 'ACADEMIC_YEAR_COMPLETED')
   where academic_year_id = p_academic_year_id
     and status in ('ACTIVE','TRANSFERRED_IN');

  update public.student_course_participations scp
     set status = 'ENDED',
         ends_on = least(coalesce(scp.ends_on, p_close_on), p_close_on)
   where scp.status = 'ACTIVE'
     and scp.course_offering_id in (
       select co.id
       from public.course_offerings co
       where co.academic_year_id = p_academic_year_id
     );

  update public.teacher_assignments ta
     set active = false,
         ends_on = least(coalesce(ta.ends_on, p_close_on), p_close_on)
   where ta.active
     and ta.course_offering_id in (
       select co.id
       from public.course_offerings co
       where co.academic_year_id = p_academic_year_id
     );

  update public.class_placements cp
     set status = 'ENDED',
         ends_on = least(coalesce(cp.ends_on, p_close_on), p_close_on)
   where cp.status = 'ACTIVE'
     and cp.enrollment_id in (
       select e.id
       from public.student_enrollments e
       where e.academic_year_id = p_academic_year_id
     );

  update public.schedule_entries
     set status = 'ENDED',
         valid_until = least(coalesce(valid_until, p_close_on), p_close_on),
         updated_at = now()
   where academic_year_id = p_academic_year_id
     and status in ('DRAFT','ACTIVE');

  update public.course_offerings
     set status = 'CLOSED'
   where academic_year_id = p_academic_year_id
     and status <> 'CLOSED';

  update public.class_groups
     set status = 'CLOSED'
   where academic_year_id = p_academic_year_id
     and status <> 'CLOSED';

  update public.academic_years
     set status = 'CLOSED',
         closed_at = now(),
         closed_by = actor
   where id = p_academic_year_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id,
    reason, after_data
  )
  values (
    school_id, actor, 'CLOSE_ACADEMIC_YEAR', 'academic_year',
    p_academic_year_id, p_reason,
    jsonb_build_object(
      'status', 'CLOSED',
      'close_on', p_close_on,
      'completed_enrollments', active_enrollments
    )
  );

  result := jsonb_build_object(
    'academic_year_id', p_academic_year_id,
    'status', 'CLOSED',
    'close_on', p_close_on,
    'completed_enrollments', active_enrollments
  );

  perform private.complete_command('close_academic_year', school_id, p_idempotency_key, result);
  return result;
end;
$$;


