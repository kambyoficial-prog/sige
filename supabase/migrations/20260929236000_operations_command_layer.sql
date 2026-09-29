-- SIGE 0036 — Operations command layer
--
-- The timetable tables already enforce hard overlap/context invariants. This
-- layer makes the operational write path explicit, idempotent and auditable.

create or replace function public.create_room(
  p_school_id uuid, p_code text, p_name text, p_capacity integer default null,
  p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); room_id uuid; result jsonb; command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_code is null or length(trim(p_code)) = 0 then raise exception 'ROOM_CODE_REQUIRED'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'ROOM_NAME_REQUIRED'; end if;
  if p_capacity is not null and p_capacity <= 0 then raise exception 'INVALID_ROOM_CAPACITY'; end if;
  if not (select private.has_permission('operations.manage', p_school_id)) then raise exception 'FORBIDDEN'; end if;
  command_state := private.begin_command('create_room', p_school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;
  insert into public.rooms (school_id, code, name, capacity)
  values (p_school_id, upper(trim(p_code)), trim(p_name), p_capacity) returning id into room_id;
  result := jsonb_build_object('room_id', room_id);
  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values (p_school_id, actor, 'CREATE_ROOM', 'room', room_id, result);
  perform private.complete_command('create_room', p_school_id, p_idempotency_key, result);
  return result;
end $$;

create or replace function public.create_schedule_period(
  p_school_id uuid, p_code text, p_name text, p_ordinal integer,
  p_starts_at time, p_ends_at time,
  p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); period_id uuid; result jsonb; command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_code is null or length(trim(p_code)) = 0 then raise exception 'PERIOD_CODE_REQUIRED'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'PERIOD_NAME_REQUIRED'; end if;
  if p_ordinal <= 0 then raise exception 'INVALID_PERIOD_ORDINAL'; end if;
  if p_ends_at <= p_starts_at then raise exception 'INVALID_PERIOD_RANGE'; end if;
  if not (select private.has_permission('operations.manage', p_school_id)) then raise exception 'FORBIDDEN'; end if;
  command_state := private.begin_command('create_schedule_period', p_school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;
  insert into public.schedule_periods (school_id, code, name, ordinal, starts_at, ends_at)
  values (p_school_id, upper(trim(p_code)), trim(p_name), p_ordinal, p_starts_at, p_ends_at)
  returning id into period_id;
  result := jsonb_build_object('schedule_period_id', period_id);
  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values (p_school_id, actor, 'CREATE_SCHEDULE_PERIOD', 'schedule_period', period_id, result);
  perform private.complete_command('create_schedule_period', p_school_id, p_idempotency_key, result);
  return result;
end $$;

create or replace function public.upsert_school_calendar_day(
  p_academic_year_id uuid, p_school_date date, p_instructional boolean default true,
  p_label text default null, p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); school_id uuid; year_start date; year_end date;
day_id uuid; result jsonb; command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select ay.school_id, ay.starts_on, ay.ends_on into school_id, year_start, year_end
  from public.academic_years ay where ay.id = p_academic_year_id for update;
  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if p_school_date < year_start or p_school_date > year_end then raise exception 'CALENDAR_DATE_OUTSIDE_ACADEMIC_YEAR'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then raise exception 'FORBIDDEN'; end if;
  command_state := private.begin_command('upsert_school_calendar_day', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;
  insert into public.school_calendar_days (academic_year_id, school_date, instructional, label)
  values (p_academic_year_id, p_school_date, p_instructional, nullif(trim(p_label), ''))
  on conflict (academic_year_id, school_date)
  do update set instructional = excluded.instructional, label = excluded.label
  returning id into day_id;
  result := jsonb_build_object('school_calendar_day_id', day_id, 'school_date', p_school_date);
  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values (school_id, actor, 'UPSERT_SCHOOL_CALENDAR_DAY', 'school_calendar_day', day_id, result);
  perform private.complete_command('upsert_school_calendar_day', school_id, p_idempotency_key, result);
  return result;
end $$;

create or replace function public.create_schedule_entry(
  p_academic_year_id uuid, p_class_group_id uuid, p_course_offering_id uuid,
  p_teacher_assignment_id uuid, p_teacher_id uuid, p_room_id uuid, p_period_id uuid,
  p_day_of_week smallint, p_valid_from date, p_valid_until date default null,
  p_notes text default null, p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); school_id uuid; year_start date; year_end date;
assignment_start date; assignment_end date; entry_id uuid; result jsonb; command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_day_of_week not between 1 and 7 then raise exception 'INVALID_DAY_OF_WEEK'; end if;
  if p_valid_until is not null and p_valid_until < p_valid_from then raise exception 'INVALID_SCHEDULE_DATES'; end if;
  select ay.school_id, ay.starts_on, ay.ends_on into school_id, year_start, year_end
  from public.academic_years ay where ay.id = p_academic_year_id for update;
  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if p_valid_from < year_start or p_valid_from > year_end
     or (p_valid_until is not null and p_valid_until > year_end) then
    raise exception 'SCHEDULE_DATES_OUTSIDE_ACADEMIC_YEAR';
  end if;
  if not (select private.has_permission('operations.manage', school_id)) then raise exception 'FORBIDDEN'; end if;
  select ta.starts_on, ta.ends_on into assignment_start, assignment_end
  from public.teacher_assignments ta
  where ta.id = p_teacher_assignment_id and ta.teacher_id = p_teacher_id
    and ta.course_offering_id = p_course_offering_id and ta.active;
  if not found then raise exception 'TEACHER_ASSIGNMENT_NOT_FOUND'; end if;
  if p_valid_from < assignment_start
     or (assignment_end is not null and p_valid_until is not null and p_valid_until > assignment_end)
     or (assignment_end is not null and p_valid_until is null and assignment_end < year_end) then
    raise exception 'SCHEDULE_OUTSIDE_TEACHER_ASSIGNMENT';
  end if;
  command_state := private.begin_command('create_schedule_entry', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;
  insert into public.schedule_entries (
    school_id, academic_year_id, class_group_id, course_offering_id,
    teacher_assignment_id, teacher_id, room_id, period_id, day_of_week,
    valid_from, valid_until, notes, status
  ) values (
    school_id, p_academic_year_id, p_class_group_id, p_course_offering_id,
    p_teacher_assignment_id, p_teacher_id, p_room_id, p_period_id, p_day_of_week,
    p_valid_from, p_valid_until, nullif(trim(p_notes), ''), 'DRAFT'
  ) returning id into entry_id;
  result := jsonb_build_object('schedule_entry_id', entry_id, 'status', 'DRAFT');
  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values (school_id, actor, 'CREATE_SCHEDULE_ENTRY', 'schedule_entry', entry_id, result);
  perform private.complete_command('create_schedule_entry', school_id, p_idempotency_key, result);
  return result;
end $$;

create or replace function public.set_schedule_entry_status(
  p_schedule_entry_id uuid, p_status public.schedule_entry_status,
  p_reason text default null, p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); school_id uuid; current_status public.schedule_entry_status;
result jsonb; command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select se.school_id, se.status into school_id, current_status
  from public.schedule_entries se where se.id = p_schedule_entry_id for update;
  if school_id is null then raise exception 'SCHEDULE_ENTRY_NOT_FOUND'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then raise exception 'FORBIDDEN'; end if;
  if not ((current_status = 'DRAFT' and p_status in ('ACTIVE','CANCELLED'))
       or (current_status = 'ACTIVE' and p_status in ('ENDED','CANCELLED'))) then
    raise exception 'INVALID_SCHEDULE_STATUS_TRANSITION';
  end if;
  command_state := private.begin_command('set_schedule_entry_status', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;
  update public.schedule_entries set status = p_status, updated_at = now()
  where id = p_schedule_entry_id;
  result := jsonb_build_object('schedule_entry_id', p_schedule_entry_id, 'previous_status', current_status, 'status', p_status);
  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, reason, after_data)
  values (school_id, actor, 'SET_SCHEDULE_ENTRY_STATUS', 'schedule_entry', p_schedule_entry_id, nullif(trim(p_reason), ''), result);
  perform private.complete_command('set_schedule_entry_status', school_id, p_idempotency_key, result);
  return result;
end $$;

revoke all on function public.create_room(uuid,text,text,integer,text,text) from public;
revoke all on function public.create_schedule_period(uuid,text,text,integer,time,time,text,text) from public;
revoke all on function public.upsert_school_calendar_day(uuid,date,boolean,text,text,text) from public;
revoke all on function public.create_schedule_entry(uuid,uuid,uuid,uuid,uuid,uuid,uuid,smallint,date,date,text,text,text) from public;
revoke all on function public.set_schedule_entry_status(uuid,public.schedule_entry_status,text,text,text) from public;

grant execute on function public.create_room(uuid,text,text,integer,text,text) to authenticated;
grant execute on function public.create_schedule_period(uuid,text,text,integer,time,time,text,text) to authenticated;
grant execute on function public.upsert_school_calendar_day(uuid,date,boolean,text,text,text) to authenticated;
grant execute on function public.create_schedule_entry(uuid,uuid,uuid,uuid,uuid,uuid,uuid,smallint,date,date,text,text,text) to authenticated;
grant execute on function public.set_schedule_entry_status(uuid,public.schedule_entry_status,text,text,text) to authenticated;

alter function public.create_room(uuid,text,text,integer,text,text) set search_path = '';
alter function public.create_schedule_period(uuid,text,text,integer,time,time,text,text) set search_path = '';
alter function public.upsert_school_calendar_day(uuid,date,boolean,text,text,text) set search_path = '';
alter function public.create_schedule_entry(uuid,uuid,uuid,uuid,uuid,uuid,uuid,smallint,date,date,text,text,text) set search_path = '';
alter function public.set_schedule_entry_status(uuid,public.schedule_entry_status,text,text,text) set search_path = '';

revoke insert, update, delete on public.rooms from authenticated;
revoke insert, update, delete on public.schedule_periods from authenticated;
revoke insert, update, delete on public.school_calendar_days from authenticated;
revoke insert, update, delete on public.schedule_entries from authenticated;
