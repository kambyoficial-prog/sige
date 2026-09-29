-- SIGE 0034 — closed academic year write barrier
--
-- Commands are the preferred mutation path, but the database must also reject
-- direct writes against operational records belonging to a CLOSED year.

create or replace function private.guard_closed_academic_year_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_id uuid;
begin
  if tg_table_name = 'academic_years' then
    year_id := coalesce(new.id, old.id);
  elsif tg_table_name in ('student_enrollments','class_groups','course_offerings',
                          'assessment_periods','curriculum_subjects','school_calendar_days',
                          'academic_results') then
    year_id := coalesce(new.academic_year_id, old.academic_year_id);
  elsif tg_table_name = 'class_placements' then
    select e.academic_year_id into year_id
    from public.student_enrollments e
    where e.id = coalesce(new.enrollment_id, old.enrollment_id);
  elsif tg_table_name = 'student_course_participations' then
    select co.academic_year_id into year_id
    from public.course_offerings co
    where co.id = coalesce(new.course_offering_id, old.course_offering_id);
  elsif tg_table_name = 'teacher_assignments' then
    select co.academic_year_id into year_id
    from public.course_offerings co
    where co.id = coalesce(new.course_offering_id, old.course_offering_id);
  elsif tg_table_name = 'schedule_entries' then
    year_id := coalesce(new.academic_year_id, old.academic_year_id);
  elsif tg_table_name = 'class_sessions' then
    select se.academic_year_id into year_id
    from public.schedule_entries se
    where se.id = coalesce(new.schedule_entry_id, old.schedule_entry_id);
  elsif tg_table_name = 'attendance_records' then
    select se.academic_year_id into year_id
    from public.class_sessions cs
    join public.schedule_entries se on se.id = cs.schedule_entry_id
    where cs.id = coalesce(new.class_session_id, old.class_session_id);
  end if;

  if year_id is null then
    raise exception 'ACADEMIC_YEAR_CONTEXT_NOT_FOUND';
  end if;

  perform private.assert_academic_year_mutable(year_id);

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_closed_academic_year_mutation() from public;

drop trigger if exists trg_closed_year_student_enrollments on public.student_enrollments;
create trigger trg_closed_year_student_enrollments
before insert or update or delete on public.student_enrollments
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_class_groups on public.class_groups;
create trigger trg_closed_year_class_groups
before insert or update or delete on public.class_groups
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_course_offerings on public.course_offerings;
create trigger trg_closed_year_course_offerings
before insert or update or delete on public.course_offerings
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_assessment_periods on public.assessment_periods;
create trigger trg_closed_year_assessment_periods
before insert or update or delete on public.assessment_periods
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_curriculum_subjects on public.curriculum_subjects;
create trigger trg_closed_year_curriculum_subjects
before insert or update or delete on public.curriculum_subjects
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_school_calendar_days on public.school_calendar_days;
create trigger trg_closed_year_school_calendar_days
before insert or update or delete on public.school_calendar_days
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_class_placements on public.class_placements;
create trigger trg_closed_year_class_placements
before insert or update or delete on public.class_placements
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_student_course_participations on public.student_course_participations;
create trigger trg_closed_year_student_course_participations
before insert or update or delete on public.student_course_participations
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_teacher_assignments on public.teacher_assignments;
create trigger trg_closed_year_teacher_assignments
before insert or update or delete on public.teacher_assignments
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_schedule_entries on public.schedule_entries;
create trigger trg_closed_year_schedule_entries
before insert or update or delete on public.schedule_entries
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_class_sessions on public.class_sessions;
create trigger trg_closed_year_class_sessions
before insert or update or delete on public.class_sessions
for each row execute function private.guard_closed_academic_year_mutation();

drop trigger if exists trg_closed_year_attendance_records on public.attendance_records;
create trigger trg_closed_year_attendance_records
before insert or update or delete on public.attendance_records
for each row execute function private.guard_closed_academic_year_mutation();

comment on function private.guard_closed_academic_year_mutation() is
  'Database-level write barrier for operational records belonging to closed academic years.';
