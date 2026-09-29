-- SIGE 0010 — Harden timetable cross-entity integrity

alter table public.schedule_entries
  add column teacher_id uuid references public.teachers(id) on delete restrict;

update public.schedule_entries se
set teacher_id = ta.teacher_id
from public.teacher_assignments ta
where ta.id = se.teacher_assignment_id;

alter table public.schedule_entries
  alter column teacher_id set not null;

alter table public.schedule_entries
  drop constraint schedule_teacher_no_overlap;

alter table public.schedule_entries
  add constraint schedule_teacher_no_overlap
  exclude using gist (
    (teacher_id) with =,
    (day_of_week) with =,
    (period_id) with =,
    daterange(valid_from, coalesce(valid_until + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status in ('DRAFT','ACTIVE'));

create index schedule_entries_teacher_id_idx
  on public.schedule_entries (teacher_id, day_of_week, period_id);

create or replace function private.validate_schedule_entry_context()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  ta_teacher uuid;
  ta_offering uuid;
  offering_class uuid;
  offering_school uuid;
  offering_year uuid;
  period_school uuid;
  room_school uuid;
begin
  select ta.teacher_id, ta.course_offering_id
    into ta_teacher, ta_offering
  from public.teacher_assignments ta
  where ta.id = new.teacher_assignment_id;

  if ta_teacher is null then
    raise exception 'Teacher assignment % does not exist', new.teacher_assignment_id;
  end if;

  if new.teacher_id <> ta_teacher then
    raise exception 'Schedule teacher does not match teacher assignment';
  end if;

  if new.course_offering_id <> ta_offering then
    raise exception 'Schedule course offering does not match teacher assignment';
  end if;

  select co.class_group_id, co.school_id, co.academic_year_id
    into offering_class, offering_school, offering_year
  from public.course_offerings co
  where co.id = new.course_offering_id;

  if offering_class is null then
    raise exception 'Course offering % does not exist', new.course_offering_id;
  end if;

  if new.class_group_id <> offering_class then
    raise exception 'Schedule class group does not match course offering';
  end if;

  if new.school_id <> offering_school then
    raise exception 'Schedule school does not match course offering';
  end if;

  if new.academic_year_id <> offering_year then
    raise exception 'Schedule academic year does not match course offering';
  end if;

  select sp.school_id into period_school
  from public.schedule_periods sp
  where sp.id = new.period_id;

  if period_school <> new.school_id then
    raise exception 'Schedule period belongs to another school';
  end if;

  if new.room_id is not null then
    select r.school_id into room_school
    from public.rooms r
    where r.id = new.room_id;

    if room_school <> new.school_id then
      raise exception 'Schedule room belongs to another school';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_schedule_entry_context on public.schedule_entries;
create trigger trg_validate_schedule_entry_context
before insert or update on public.schedule_entries
for each row execute function private.validate_schedule_entry_context();

create or replace function private.validate_class_session_context()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  schedule_teacher uuid;
  schedule_offering uuid;
begin
  select se.teacher_id, se.course_offering_id
    into schedule_teacher, schedule_offering
  from public.schedule_entries se
  where se.id = new.schedule_entry_id;

  if schedule_teacher is null then
    raise exception 'Schedule entry % does not exist', new.schedule_entry_id;
  end if;

  if new.teacher_id <> schedule_teacher then
    raise exception 'Class session teacher does not match schedule entry';
  end if;

  if new.course_offering_id <> schedule_offering then
    raise exception 'Class session offering does not match schedule entry';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_class_session_context on public.class_sessions;
create trigger trg_validate_class_session_context
before insert or update on public.class_sessions
for each row execute function private.validate_class_session_context();
