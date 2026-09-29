-- SIGE F5 — class session command boundary and operational projections
-- Sessions are the unit of classroom operation. Attendance belongs to a session.

alter table public.class_sessions
  drop constraint if exists class_sessions_status_ck;

alter table public.class_sessions
  add constraint class_sessions_status_ck
  check (status in ('PLANNED','OPEN','CLOSED','CANCELLED'));

create or replace function public.open_class_session(
  p_schedule_entry_id uuid,
  p_session_date date,
  p_topic text default null,
  p_notes text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  year_id uuid;
  entry_teacher_id uuid;
  offering_id uuid;
  class_id uuid;
  entry_status public.schedule_entry_status;
  day_of_week smallint;
  valid_from date;
  valid_until date;
  year_start date;
  year_end date;
  instructional boolean;
  session_id uuid;
  current_status text;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_session_date is null then raise exception 'SESSION_DATE_REQUIRED'; end if;

  select
    se.school_id, se.academic_year_id, se.teacher_id, se.course_offering_id,
    se.class_group_id, se.status, se.day_of_week, se.valid_from, se.valid_until,
    ay.starts_on, ay.ends_on
  into
    school_id, year_id, entry_teacher_id, offering_id,
    class_id, entry_status, day_of_week, valid_from, valid_until,
    year_start, year_end
  from public.schedule_entries se
  join public.academic_years ay on ay.id = se.academic_year_id
  where se.id = p_schedule_entry_id
  for update;

  if school_id is null then raise exception 'SCHEDULE_ENTRY_NOT_FOUND'; end if;
  if entry_status <> 'ACTIVE' then raise exception 'SCHEDULE_ENTRY_NOT_OPENABLE'; end if;
  if p_session_date < year_start or p_session_date > year_end then
    raise exception 'SESSION_DATE_OUTSIDE_ACADEMIC_YEAR';
  end if;
  if p_session_date < valid_from
     or (valid_until is not null and p_session_date > valid_until) then
    raise exception 'SESSION_DATE_OUTSIDE_SCHEDULE_VALIDITY';
  end if;
  if extract(isodow from p_session_date)::smallint <> day_of_week then
    raise exception 'SESSION_DATE_NOT_ON_SCHEDULE_DAY';
  end if;

  select scd.instructional
    into instructional
  from public.school_calendar_days scd
  where scd.academic_year_id = year_id
    and scd.school_date = p_session_date;

  if coalesce(instructional, true) = false then
    raise exception 'SESSION_DATE_NON_INSTRUCTIONAL';
  end if;

  if not (
    (select private.has_permission('operations.manage', school_id))
    or (
      (select private.has_permission('attendance.own.manage', school_id))
      and exists (
        select 1
        from public.teachers t
        where t.id = entry_teacher_id
          and t.person_id = (select private.current_person_id())
      )
    )
  ) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'open_class_session', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  select cs.id, cs.status
    into session_id, current_status
  from public.class_sessions cs
  where cs.schedule_entry_id = p_schedule_entry_id
    and cs.session_date = p_session_date
  for update;

  if session_id is not null then
    if current_status = 'CLOSED' then raise exception 'SESSION_ALREADY_CLOSED'; end if;
    if current_status = 'CANCELLED' then raise exception 'SESSION_CANCELLED'; end if;

    update public.class_sessions
       set status = 'OPEN',
           topic = coalesce(nullif(trim(p_topic), ''), topic),
           notes = coalesce(nullif(trim(p_notes), ''), notes),
           updated_at = now()
     where id = session_id;
  else
    insert into public.class_sessions (
      schedule_entry_id, session_date, teacher_id, course_offering_id,
      topic, notes, status
    )
    values (
      p_schedule_entry_id, p_session_date, entry_teacher_id, offering_id,
      nullif(trim(p_topic), ''), nullif(trim(p_notes), ''), 'OPEN'
    )
    returning id into session_id;
  end if;

  result := jsonb_build_object(
    'class_session_id', session_id,
    'schedule_entry_id', p_schedule_entry_id,
    'session_date', p_session_date,
    'status', 'OPEN'
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'OPEN_CLASS_SESSION', 'class_session', session_id, result
  );

  perform private.complete_command(
    'open_class_session', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.close_class_session(
  p_class_session_id uuid,
  p_reason text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  teacher_id uuid;
  current_status text;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, cs.teacher_id, cs.status
    into school_id, teacher_id, current_status
  from public.class_sessions cs
  join public.course_offerings co on co.id = cs.course_offering_id
  where cs.id = p_class_session_id
  for update;

  if school_id is null then raise exception 'CLASS_SESSION_NOT_FOUND'; end if;
  if current_status <> 'OPEN' then raise exception 'INVALID_SESSION_STATUS_TRANSITION'; end if;

  if not (
    (select private.has_permission('operations.manage', school_id))
    or (
      (select private.has_permission('attendance.own.manage', school_id))
      and exists (
        select 1 from public.teachers t
        where t.id = teacher_id
          and t.person_id = (select private.current_person_id())
      )
    )
  ) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'close_class_session', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.class_sessions
     set status = 'CLOSED',
         notes = coalesce(nullif(trim(p_reason), ''), notes),
         updated_at = now()
   where id = p_class_session_id;

  result := jsonb_build_object(
    'class_session_id', p_class_session_id,
    'previous_status', current_status,
    'status', 'CLOSED'
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, reason, after_data
  )
  values (
    school_id, actor, 'CLOSE_CLASS_SESSION', 'class_session',
    p_class_session_id, nullif(trim(p_reason), ''), result
  );

  perform private.complete_command(
    'close_class_session', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.record_session_attendance(
  p_class_session_id uuid,
  p_student_id uuid,
  p_status public.attendance_status,
  p_minutes_late integer default null,
  p_reason text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  teacher_id uuid;
  class_id uuid;
  session_date date;
  current_status text;
  enrollment_id uuid;
  attendance_id uuid;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_minutes_late is not null and p_minutes_late < 0 then
    raise exception 'INVALID_LATE_MINUTES';
  end if;
  if p_status = 'LATE' and coalesce(p_minutes_late, 0) = 0 then
    raise exception 'LATE_MINUTES_REQUIRED';
  end if;
  if p_status <> 'LATE' and p_minutes_late is not null then
    raise exception 'LATE_MINUTES_ONLY_FOR_LATE_STATUS';
  end if;

  select co.school_id, cs.teacher_id, cs.status, cs.session_date, se.class_group_id
    into school_id, teacher_id, current_status, session_date, class_id
  from public.class_sessions cs
  join public.course_offerings co on co.id = cs.course_offering_id
  join public.schedule_entries se on se.id = cs.schedule_entry_id
  where cs.id = p_class_session_id
  for update;

  if school_id is null then raise exception 'CLASS_SESSION_NOT_FOUND'; end if;
  if current_status <> 'OPEN' then raise exception 'SESSION_NOT_OPEN'; end if;

  if not (
    (select private.has_permission('operations.manage', school_id))
    or (
      (select private.has_permission('attendance.own.manage', school_id))
      and exists (
        select 1 from public.teachers t
        where t.id = teacher_id
          and t.person_id = (select private.current_person_id())
      )
    )
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select e.id into enrollment_id
  from public.student_enrollments e
  join public.class_placements cp on cp.enrollment_id = e.id
  where e.student_id = p_student_id
    and e.academic_year_id = (
      select se.academic_year_id
      from public.class_sessions cs
      join public.schedule_entries se on se.id = cs.schedule_entry_id
      where cs.id = p_class_session_id
    )
    and cp.class_group_id = class_id
    and cp.status = 'ACTIVE'
    and cp.starts_on <= session_date
    and (cp.ends_on is null or cp.ends_on >= session_date)
  limit 1;

  if enrollment_id is null then raise exception 'STUDENT_NOT_IN_CLASS'; end if;

  command_state := private.begin_command(
    'record_session_attendance', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.attendance_records (
    class_session_id, student_id, status, minutes_late, reason, recorded_by
  )
  values (
    p_class_session_id, p_student_id, p_status, p_minutes_late,
    nullif(trim(p_reason), ''), actor
  )
  on conflict (class_session_id, student_id)
  do update set
    status = excluded.status,
    minutes_late = excluded.minutes_late,
    reason = excluded.reason,
    recorded_by = actor,
    updated_at = now()
  returning id into attendance_id;

  result := jsonb_build_object(
    'attendance_record_id', attendance_id,
    'class_session_id', p_class_session_id,
    'student_id', p_student_id,
    'status', p_status
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'RECORD_SESSION_ATTENDANCE',
    'attendance_record', attendance_id, result
  );

  perform private.complete_command(
    'record_session_attendance', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.open_class_session(uuid,date,text,text,text,text) from public;
revoke all on function public.close_class_session(uuid,text,text,text) from public;
revoke all on function public.record_session_attendance(uuid,uuid,public.attendance_status,integer,text,text,text) from public;

grant execute on function public.open_class_session(uuid,date,text,text,text,text) to authenticated;
grant execute on function public.close_class_session(uuid,text,text,text) to authenticated;
grant execute on function public.record_session_attendance(uuid,uuid,public.attendance_status,integer,text,text,text) to authenticated;

alter function public.open_class_session(uuid,date,text,text,text,text) set search_path = '';
alter function public.close_class_session(uuid,text,text,text) set search_path = '';
alter function public.record_session_attendance(uuid,uuid,public.attendance_status,integer,text,text,text) set search_path = '';

-- The command boundary is now authoritative for operational writes.
drop policy if exists sessions_manage on public.class_sessions;
drop policy if exists attendance_manage on public.attendance_records;
revoke insert, update, delete on public.class_sessions from authenticated;
revoke insert, update, delete on public.attendance_records from authenticated;

create or replace view public.class_session_directory
with (security_invoker = true)
as
select
  cs.id,
  co.school_id,
  se.academic_year_id,
  cs.session_date,
  cs.status,
  cs.topic,
  cs.notes,
  cs.schedule_entry_id,
  cs.teacher_id,
  tp.full_name as teacher_name,
  cs.course_offering_id,
  sub.code as subject_code,
  sub.name as subject_name,
  se.class_group_id,
  cg.section_code,
  cg.name as class_name,
  sp.ordinal as period_ordinal,
  sp.code as period_code,
  sp.name as period_name,
  sp.starts_at,
  sp.ends_at,
  se.room_id,
  r.code as room_code,
  r.name as room_name,
  count(ar.id)::integer as attendance_count
from public.class_sessions cs
join public.schedule_entries se on se.id = cs.schedule_entry_id
join public.course_offerings co on co.id = cs.course_offering_id
join public.subjects sub on sub.id = co.subject_id
join public.class_groups cg on cg.id = se.class_group_id
join public.teachers t on t.id = cs.teacher_id
join public.people tp on tp.id = t.person_id
join public.schedule_periods sp on sp.id = se.period_id
left join public.rooms r on r.id = se.room_id
left join public.attendance_records ar on ar.class_session_id = cs.id
group by
  cs.id, co.school_id, se.academic_year_id, cs.session_date, cs.status,
  cs.topic, cs.notes, cs.schedule_entry_id, cs.teacher_id, tp.full_name,
  cs.course_offering_id, sub.code, sub.name, se.class_group_id,
  cg.section_code, cg.name, sp.ordinal, sp.code, sp.name,
  sp.starts_at, sp.ends_at, se.room_id, r.code, r.name;

create or replace view public.class_session_roster
with (security_invoker = true)
as
select
  cs.id as class_session_id,
  cs.session_date,
  cs.status as session_status,
  cp.class_group_id,
  e.id as enrollment_id,
  s.id as student_id,
  s.school_number,
  p.full_name as student_name,
  ar.id as attendance_record_id,
  ar.status as attendance_status,
  ar.minutes_late,
  ar.reason,
  ar.recorded_at
from public.class_sessions cs
join public.schedule_entries se on se.id = cs.schedule_entry_id
join public.student_enrollments e
  on e.academic_year_id = se.academic_year_id
join public.class_placements cp
  on cp.enrollment_id = e.id
 and cp.class_group_id = se.class_group_id
 and cp.status = 'ACTIVE'
 and cp.starts_on <= cs.session_date
 and (cp.ends_on is null or cp.ends_on >= cs.session_date)
join public.students s on s.id = e.student_id
join public.people p on p.id = s.person_id
left join public.attendance_records ar
  on ar.class_session_id = cs.id
 and ar.student_id = s.id;

grant select on public.class_session_directory, public.class_session_roster to authenticated;

create index if not exists class_sessions_schedule_date_idx
  on public.class_sessions (schedule_entry_id, session_date, status);

create index if not exists attendance_records_session_status_idx
  on public.attendance_records (class_session_id, status);
