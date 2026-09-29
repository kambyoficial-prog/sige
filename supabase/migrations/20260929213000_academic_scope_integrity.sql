-- SIGE 0030 — cross-aggregate school and academic-context integrity
--
-- Foreign keys prove existence, but not contextual ownership. These guards
-- ensure an academic graph cannot cross school boundaries.

create or replace function private.validate_academic_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_school uuid;
  parent_school uuid;
  year_id uuid;
  grade_id uuid;
  offering_year uuid;
  offering_class_group uuid;
  offering_school uuid;
  class_year uuid;
  class_school uuid;
  teacher_school uuid;
  student_school uuid;
  subject_school uuid;
  curriculum_school uuid;
  curriculum_year uuid;
  curriculum_grade uuid;
  period_year uuid;
  session_offering uuid;
  session_teacher uuid;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_table_name = 'curriculum_subjects' then
    select ay.school_id into expected_school
    from public.academic_years ay where ay.id = new.academic_year_id;
    if expected_school is null or expected_school <> new.school_id then
      raise exception 'ACADEMIC_SCOPE_SCHOOL_MISMATCH';
    end if;

    select s.school_id into subject_school
    from public.subjects s where s.id = new.subject_id;
    if subject_school is not null and subject_school <> new.school_id then
      raise exception 'SUBJECT_SCHOOL_MISMATCH';
    end if;

    return new;
  end if;

  if tg_table_name = 'class_groups' then
    select ay.school_id into parent_school
    from public.academic_years ay where ay.id = new.academic_year_id;
    if parent_school is null or parent_school <> new.school_id then
      raise exception 'CLASS_GROUP_YEAR_SCHOOL_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'course_offerings' then
    select ay.school_id, co.academic_year_id into parent_school, year_id
    from public.academic_years ay
    join public.course_offerings co on co.academic_year_id = ay.id
    where co.id = new.id;

    select ay.school_id into parent_school
    from public.academic_years ay where ay.id = new.academic_year_id;
    if parent_school is null or parent_school <> new.school_id then
      raise exception 'COURSE_OFFERING_YEAR_SCHOOL_MISMATCH';
    end if;

    select cg.school_id, cg.academic_year_id
      into class_school, class_year
    from public.class_groups cg where cg.id = new.class_group_id;
    if class_school is null or class_school <> new.school_id or class_year <> new.academic_year_id then
      raise exception 'COURSE_OFFERING_CLASS_CONTEXT_MISMATCH';
    end if;

    select s.school_id into subject_school
    from public.subjects s where s.id = new.subject_id;
    if subject_school is not null and subject_school <> new.school_id then
      raise exception 'COURSE_OFFERING_SUBJECT_SCHOOL_MISMATCH';
    end if;

    if new.curriculum_subject_id is not null then
      select cs.school_id, cs.academic_year_id, cs.grade_level_id
        into curriculum_school, curriculum_year, curriculum_grade
      from public.curriculum_subjects cs
      where cs.id = new.curriculum_subject_id;
      if curriculum_school is null
         or curriculum_school <> new.school_id
         or curriculum_year <> new.academic_year_id
         or curriculum_grade <> (select grade_level_id from public.class_groups where id=new.class_group_id)
         or (select subject_id from public.curriculum_subjects where id=new.curriculum_subject_id) <> new.subject_id then
        raise exception 'COURSE_OFFERING_CURRICULUM_CONTEXT_MISMATCH';
      end if;
    end if;

    return new;
  end if;

  if tg_table_name = 'student_enrollments' then
    select s.school_id into student_school from public.students s where s.id=new.student_id;
    select ay.school_id into parent_school from public.academic_years ay where ay.id=new.academic_year_id;
    if student_school is null or parent_school is null or student_school <> parent_school then
      raise exception 'ENROLLMENT_SCHOOL_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'class_placements' then
    select s.school_id, e.academic_year_id into student_school, year_id
    from public.student_enrollments e
    join public.students s on s.id=e.student_id
    where e.id=new.enrollment_id;
    select cg.school_id, cg.academic_year_id into class_school, class_year
    from public.class_groups cg where cg.id=new.class_group_id;
    if student_school is null or class_school is null or student_school <> class_school or year_id <> class_year then
      raise exception 'CLASS_PLACEMENT_CONTEXT_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'student_course_participations' then
    select co.school_id, co.academic_year_id, co.class_group_id
      into offering_school, offering_year, offering_class_group
    from public.course_offerings co
    where co.id=new.course_offering_id;
    select s.school_id into student_school from public.students s where s.id=new.student_id;
    if offering_school is null or student_school is null or offering_school <> student_school then
      raise exception 'COURSE_PARTICIPATION_SCHOOL_MISMATCH';
    end if;

    if not exists (
      select 1
      from public.student_enrollments e
      where e.student_id = new.student_id
        and e.academic_year_id = offering_year
        and e.status in ('ACTIVE','TRANSFERRED_IN')
    ) then
      raise exception 'COURSE_PARTICIPATION_ENROLLMENT_CONTEXT_MISMATCH';
    end if;

    if not exists (
      select 1
      from public.class_placements cp
      where cp.enrollment_id in (
        select e.id from public.student_enrollments e
        where e.student_id = new.student_id
          and e.academic_year_id = offering_year
      )
        and cp.class_group_id = offering_class_group
        and cp.starts_on <= new.starts_on
        and (cp.ends_on is null or cp.ends_on >= new.starts_on)
    ) then
      raise exception 'COURSE_PARTICIPATION_CLASS_CONTEXT_MISMATCH';
    end if;

    return new;
  end if;

  if tg_table_name = 'teacher_assignments' then
    select co.school_id, co.academic_year_id into offering_school, offering_year
    from public.course_offerings co where co.id=new.course_offering_id;
    select t.school_id into teacher_school from public.teachers t where t.id=new.teacher_id;
    if offering_school is null or teacher_school is null or offering_school <> teacher_school then
      raise exception 'TEACHER_ASSIGNMENT_SCHOOL_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'assessment_periods' then
    select ay.school_id into expected_school
    from public.academic_years ay where ay.id=new.academic_year_id;
    if expected_school is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
    return new;
  end if;

  if tg_table_name = 'assessments' then
    select co.school_id, co.academic_year_id into offering_school, offering_year
    from public.course_offerings co where co.id=new.course_offering_id;
    select ap.academic_year_id into period_year
    from public.assessment_periods ap where ap.id=new.assessment_period_id;
    if offering_school is null or period_year is null or period_year <> offering_year then
      raise exception 'ASSESSMENT_CONTEXT_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'assessment_results' then
    select co.school_id, co.academic_year_id into offering_school, offering_year
    from public.assessments a
    join public.course_offerings co on co.id=a.course_offering_id
    where a.id=new.assessment_id;

    select s.school_id into student_school
    from public.students s
    where s.id=new.student_id;

    if student_school is null or offering_school is null or student_school <> offering_school then
      raise exception 'ASSESSMENT_RESULT_STUDENT_SCHOOL_MISMATCH';
    end if;

    if not exists (
      select 1
      from public.student_course_participations scp
      where scp.student_id=new.student_id
        and scp.course_offering_id=(
          select a.course_offering_id from public.assessments a where a.id=new.assessment_id
        )
    ) then
      raise exception 'ASSESSMENT_RESULT_STUDENT_COURSE_CONTEXT_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'schedule_entries' then
    select ay.school_id into expected_school
    from public.academic_years ay where ay.id=new.academic_year_id;
    if expected_school is null or expected_school <> new.school_id then
      raise exception 'SCHEDULE_YEAR_SCHOOL_MISMATCH';
    end if;

    select cg.school_id, cg.academic_year_id into class_school, class_year
    from public.class_groups cg where cg.id=new.class_group_id;
    if class_school <> new.school_id or class_year <> new.academic_year_id then
      raise exception 'SCHEDULE_CLASS_CONTEXT_MISMATCH';
    end if;

    select co.school_id, co.academic_year_id, co.class_group_id into offering_school, offering_year, class_year
    from public.course_offerings co where co.id=new.course_offering_id;
    if offering_school <> new.school_id or offering_year <> new.academic_year_id or class_year <> new.class_group_id then
      raise exception 'SCHEDULE_OFFERING_CONTEXT_MISMATCH';
    end if;

    select ta.teacher_id, co.school_id into session_teacher, teacher_school
    from public.teacher_assignments ta
    join public.course_offerings co on co.id=ta.course_offering_id
    where ta.id=new.teacher_assignment_id;
    if teacher_school <> new.school_id or not exists (
      select 1 from public.teacher_assignments ta2
      where ta2.id=new.teacher_assignment_id
        and ta2.course_offering_id=new.course_offering_id
    ) then
      raise exception 'SCHEDULE_TEACHER_ASSIGNMENT_CONTEXT_MISMATCH';
    end if;

    if new.room_id is not null and not exists (
      select 1 from public.rooms r where r.id=new.room_id and r.school_id=new.school_id
    ) then
      raise exception 'SCHEDULE_ROOM_SCHOOL_MISMATCH';
    end if;

    if not exists (
      select 1 from public.schedule_periods sp
      where sp.id=new.period_id and sp.school_id=new.school_id
    ) then
      raise exception 'SCHEDULE_PERIOD_SCHOOL_MISMATCH';
    end if;

    return new;
  end if;

  if tg_table_name = 'class_sessions' then
    select se.school_id, se.academic_year_id, se.course_offering_id
      into expected_school, year_id, session_offering
    from public.schedule_entries se where se.id=new.schedule_entry_id;
    select co.school_id into offering_school from public.course_offerings co where co.id=new.course_offering_id;
    select t.school_id into teacher_school from public.teachers t where t.id=new.teacher_id;
    if expected_school is null or offering_school <> expected_school or session_offering <> new.course_offering_id
       or teacher_school <> expected_school then
      raise exception 'CLASS_SESSION_CONTEXT_MISMATCH';
    end if;
    return new;
  end if;

  if tg_table_name = 'attendance_records' then
    select cs.course_offering_id into session_offering
    from public.class_sessions cs where cs.id=new.class_session_id;
    if not exists (
      select 1
      from public.student_course_participations scp
      where scp.student_id=new.student_id
        and scp.course_offering_id=session_offering
        and scp.starts_on <= (select session_date from public.class_sessions where id=new.class_session_id)
        and (scp.ends_on is null or scp.ends_on >= (select session_date from public.class_sessions where id=new.class_session_id))
    ) then
      raise exception 'ATTENDANCE_STUDENT_NOT_IN_COURSE_CONTEXT';
    end if;
    return new;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_academic_scope() from public;

drop trigger if exists trg_validate_curriculum_scope on public.curriculum_subjects;
create trigger trg_validate_curriculum_scope before insert or update on public.curriculum_subjects
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_class_group_scope on public.class_groups;
create trigger trg_validate_class_group_scope before insert or update on public.class_groups
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_course_offering_scope on public.course_offerings;
create trigger trg_validate_course_offering_scope before insert or update on public.course_offerings
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_enrollment_scope on public.student_enrollments;
create trigger trg_validate_enrollment_scope before insert or update on public.student_enrollments
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_class_placement_scope on public.class_placements;
create trigger trg_validate_class_placement_scope before insert or update on public.class_placements
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_course_participation_scope on public.student_course_participations;
create trigger trg_validate_course_participation_scope before insert or update on public.student_course_participations
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_teacher_assignment_scope on public.teacher_assignments;
create trigger trg_validate_teacher_assignment_scope before insert or update on public.teacher_assignments
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_assessment_period_scope on public.assessment_periods;
create trigger trg_validate_assessment_period_scope before insert or update on public.assessment_periods
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_assessment_scope on public.assessments;
create trigger trg_validate_assessment_scope before insert or update on public.assessments
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_assessment_result_scope on public.assessment_results;
create trigger trg_validate_assessment_result_scope before insert or update on public.assessment_results
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_schedule_entry_scope on public.schedule_entries;
create trigger trg_validate_schedule_entry_scope before insert or update on public.schedule_entries
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_class_session_scope on public.class_sessions;
create trigger trg_validate_class_session_scope before insert or update on public.class_sessions
for each row execute function private.validate_academic_scope();

drop trigger if exists trg_validate_attendance_scope on public.attendance_records;
create trigger trg_validate_attendance_scope before insert or update on public.attendance_records
for each row execute function private.validate_academic_scope();
