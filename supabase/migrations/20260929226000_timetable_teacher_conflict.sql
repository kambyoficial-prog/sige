-- SIGE 0039 — timetable teacher conflict hardening
--
-- A teacher can hold multiple assignments. Conflict detection therefore cannot
-- use teacher_assignment_id as the identity of the occupied resource.

create or replace function private.validate_schedule_teacher_conflict()
returns trigger
language plpgsql
security definer
set search_path = ''
as $sige$
declare
  v_teacher_id uuid;
  conflicting_entry uuid;
begin
  select ta.teacher_id
    into v_teacher_id
  from public.teacher_assignments ta
  where ta.id = new.teacher_assignment_id;

  if v_teacher_id is null then
    raise exception 'TEACHER_ASSIGNMENT_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.teacher_assignments ta
    where ta.id = new.teacher_assignment_id
      and ta.course_offering_id = new.course_offering_id
      and ta.starts_on <= coalesce(new.valid_until, '9999-12-31'::date)
      and (ta.ends_on is null or ta.ends_on >= new.valid_from)
  ) then
    raise exception 'TEACHER_ASSIGNMENT_CONTEXT_MISMATCH';
  end if;

  select se.id
    into conflicting_entry
  from public.schedule_entries se
  join public.teacher_assignments ta on ta.id = se.teacher_assignment_id
  where se.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    and se.school_id = new.school_id
    and se.status in ('DRAFT','ACTIVE')
    and ta.teacher_id = v_teacher_id
    and se.day_of_week = new.day_of_week
    and se.period_id = new.period_id
    and daterange(
      se.valid_from,
      coalesce(se.valid_until + 1, '9999-12-31'::date),
      '[)'
    ) &&
    daterange(
      new.valid_from,
      coalesce(new.valid_until + 1, '9999-12-31'::date),
      '[)'
    )
  limit 1;

  if conflicting_entry is not null then
    raise exception 'SCHEDULE_TEACHER_CONFLICT';
  end if;

  return new;
end;
$sige$;

revoke all on function private.validate_schedule_teacher_conflict() from public;

drop trigger if exists trg_validate_schedule_teacher_conflict on public.schedule_entries;
create trigger trg_validate_schedule_teacher_conflict
before insert or update on public.schedule_entries
for each row execute function private.validate_schedule_teacher_conflict();

comment on function private.validate_schedule_teacher_conflict() is
  'Prevents a teacher from occupying two simultaneous schedule entries even when the teacher has multiple course assignments.';
