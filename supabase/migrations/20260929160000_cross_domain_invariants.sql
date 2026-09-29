-- SIGE 0014 — Cross-domain invariants and immutable assessment history
--
-- Purpose:
-- 1. Reject cross-school / cross-year / cross-grade relationships that FK constraints
--    alone cannot express.
-- 2. Bind application accounts to a domain Person.
-- 3. Preserve a durable revision trail when a published assessment result changes.
--
-- PostgreSQL range/exclusion constraints remain the preferred mechanism for
-- temporal overlap rules; these triggers cover semantic relationships between
-- otherwise valid foreign keys.

alter table public.app_accounts
  alter column person_id set not null;

alter table public.app_accounts
  add constraint app_accounts_person_school_ck
  check (person_id is not null);

create or replace function private.validate_class_group_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ay_school uuid;
begin
  select school_id into ay_school
  from public.academic_years
  where id = new.academic_year_id;

  if ay_school is null or ay_school <> new.school_id then
    raise exception 'Class group must belong to the same school as its academic year';
  end if;

  return new;
end;
$$;

create or replace function private.validate_enrollment_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_school uuid;
  year_school uuid;
begin
  select school_id into student_school
  from public.students
  where id = new.student_id;

  select school_id into year_school
  from public.academic_years
  where id = new.academic_year_id;

  if student_school is null or year_school is null or student_school <> year_school then
    raise exception 'Enrollment student and academic year must belong to the same school';
  end if;

  return new;
end;
$$;

create or replace function private.validate_class_placement_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  e_school uuid;
  e_year uuid;
  e_grade uuid;
  c_school uuid;
  c_year uuid;
  c_grade uuid;
begin
  select s.school_id, e.academic_year_id, e.grade_level_id
    into e_school, e_year, e_grade
  from public.student_enrollments e
  join public.students s on s.id = e.student_id
  where e.id = new.enrollment_id;

  select school_id, academic_year_id, grade_level_id
    into c_school, c_year, c_grade
  from public.class_groups
  where id = new.class_group_id;

  if e_school is null or c_school is null
     or e_school <> c_school
     or e_year <> c_year
     or e_grade <> c_grade then
    raise exception 'Class placement must match enrollment school, academic year and grade level';
  end if;

  return new;
end;
$$;

create or replace function private.validate_curriculum_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ay_school uuid;
  subject_school uuid;
begin
  select school_id into ay_school
  from public.academic_years
  where id = new.academic_year_id;

  select school_id into subject_school
  from public.subjects
  where id = new.subject_id;

  if ay_school is null or ay_school <> new.school_id then
    raise exception 'Curriculum subject must match academic year school';
  end if;

  if subject_school is null or subject_school <> new.school_id then
    raise exception 'Curriculum subject must match subject school';
  end if;

  return new;
end;
$$;

create or replace function private.validate_course_offering_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ay_school uuid;
  cg_school uuid;
  cg_year uuid;
  subject_school uuid;
  curriculum_year uuid;
  curriculum_grade uuid;
  curriculum_subject uuid;
  curriculum_school uuid;
begin
  select school_id into ay_school
  from public.academic_years
  where id = new.academic_year_id;

  select school_id, academic_year_id into cg_school, cg_year
  from public.class_groups
  where id = new.class_group_id;

  select school_id into subject_school
  from public.subjects
  where id = new.subject_id;

  if new.curriculum_subject_id is not null then
    select school_id, academic_year_id, grade_level_id, subject_id
      into curriculum_school, curriculum_year, curriculum_grade, curriculum_subject
    from public.curriculum_subjects
    where id = new.curriculum_subject_id;
  end if;

  if ay_school is null or cg_school is null or subject_school is null
     or ay_school <> new.school_id
     or cg_school <> new.school_id
     or cg_year <> new.academic_year_id
     or subject_school <> new.school_id then
    raise exception 'Course offering must match school, academic year, class group and subject';
  end if;

  if new.curriculum_subject_id is not null
     and (
       curriculum_school <> new.school_id
       or curriculum_year <> new.academic_year_id
       or curriculum_grade <> (select grade_level_id from public.class_groups where id = new.class_group_id)
       or curriculum_subject <> new.subject_id
     ) then
    raise exception 'Course offering curriculum reference does not match offering context';
  end if;

  return new;
end;
$$;

create or replace function private.validate_teacher_assignment_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  teacher_school uuid;
  offering_school uuid;
  offering_year uuid;
  year_start date;
  year_end date;
begin
  select school_id into teacher_school
  from public.teachers
  where id = new.teacher_id;

  select co.school_id, co.academic_year_id, ay.starts_on, ay.ends_on
    into offering_school, offering_year, year_start, year_end
  from public.course_offerings co
  join public.academic_years ay on ay.id = co.academic_year_id
  where co.id = new.course_offering_id;

  if teacher_school is null or offering_school is null or teacher_school <> offering_school then
    raise exception 'Teacher assignment must stay inside one school';
  end if;

  if new.starts_on < year_start
     or (new.ends_on is not null and new.ends_on > year_end) then
    raise exception 'Teacher assignment dates must be inside the academic year';
  end if;

  return new;
end;
$$;

create or replace function private.validate_student_course_participation_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_school uuid;
  offering_school uuid;
  offering_year uuid;
  enrollment_id uuid;
begin
  select school_id into student_school
  from public.students
  where id = new.student_id;

  select school_id, academic_year_id into offering_school, offering_year
  from public.course_offerings
  where id = new.course_offering_id;

  if student_school is null or offering_school is null or student_school <> offering_school then
    raise exception 'Student course participation must stay inside one school';
  end if;

  select e.id into enrollment_id
  from public.student_enrollments e
  where e.student_id = new.student_id
    and e.academic_year_id = offering_year
    and e.status in ('PENDING','ACTIVE','TRANSFERRED_IN')
  limit 1;

  if enrollment_id is null then
    raise exception 'Student must have an active enrollment in the offering academic year';
  end if;

  return new;
end;
$$;

create or replace function private.validate_assessment_period_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_school uuid;
begin
  select school_id into year_school
  from public.academic_years
  where id = new.academic_year_id;

  if year_school is null then
    raise exception 'Assessment period references an unknown academic year';
  end if;

  return new;
end;
$$;

create or replace function private.validate_assessment_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  offering_year uuid;
  period_year uuid;
begin
  select academic_year_id into offering_year
  from public.course_offerings
  where id = new.course_offering_id;

  select academic_year_id into period_year
  from public.assessment_periods
  where id = new.assessment_period_id;

  if offering_year is null or period_year is null or offering_year <> period_year then
    raise exception 'Assessment and assessment period must belong to the same academic year';
  end if;

  return new;
end;
$$;

create or replace function private.validate_assessment_result_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  offering_id uuid;
  assessment_date date;
begin
  select a.course_offering_id, a.assessment_date
    into offering_id, assessment_date
  from public.assessments a
  where a.id = new.assessment_id;

  if offering_id is null then
    raise exception 'Assessment result references an unknown assessment';
  end if;

  if not exists (
    select 1
    from public.student_course_participations scp
    where scp.student_id = new.student_id
      and scp.course_offering_id = offering_id
      and scp.status = 'ACTIVE'
      and (assessment_date is null or scp.starts_on <= assessment_date)
      and (scp.ends_on is null or assessment_date is null or scp.ends_on >= assessment_date)
  ) then
    raise exception 'Student is not an active participant in the assessed course offering';
  end if;

  return new;
end;
$$;

create trigger trg_validate_class_group_context
before insert or update on public.class_groups
for each row execute function private.validate_class_group_context();

create trigger trg_validate_enrollment_context
before insert or update on public.student_enrollments
for each row execute function private.validate_enrollment_context();

create trigger trg_validate_class_placement_context
before insert or update on public.class_placements
for each row execute function private.validate_class_placement_context();

create trigger trg_validate_curriculum_context
before insert or update on public.curriculum_subjects
for each row execute function private.validate_curriculum_context();

create trigger trg_validate_course_offering_context
before insert or update on public.course_offerings
for each row execute function private.validate_course_offering_context();

create trigger trg_validate_teacher_assignment_context
before insert or update on public.teacher_assignments
for each row execute function private.validate_teacher_assignment_context();

create trigger trg_validate_student_course_participation_context
before insert or update on public.student_course_participations
for each row execute function private.validate_student_course_participation_context();

create trigger trg_validate_assessment_period_context
before insert or update on public.assessment_periods
for each row execute function private.validate_assessment_period_context();

create trigger trg_validate_assessment_context
before insert or update on public.assessments
for each row execute function private.validate_assessment_context();

create trigger trg_validate_assessment_result_context
before insert or update on public.assessment_results
for each row execute function private.validate_assessment_result_context();

-- Published assessment results are not overwritten silently.
-- The current row remains the authoritative current value; prior published
-- states are retained in a separate immutable history table.

create table public.assessment_result_history (
  id bigint generated always as identity primary key,
  assessment_result_id uuid not null references public.assessment_results(id) on delete restrict,
  revision_no integer not null,
  raw_score numeric(8,4),
  normalized_score numeric(8,4),
  status public.assessment_result_status not null,
  comment text,
  entered_by uuid references auth.users(id) on delete set null,
  entered_at timestamptz,
  published_at timestamptz,
  published_by uuid references auth.users(id) on delete set null,
  correction_reason text,
  captured_at timestamptz not null default now(),
  captured_by uuid references auth.users(id) on delete set null,
  unique (assessment_result_id, revision_no),
  constraint assessment_result_history_revision_ck check (revision_no > 0)
);

alter table public.assessment_result_history enable row level security;

create policy assessment_result_history_read
on public.assessment_result_history
for select to authenticated
using (
  exists (
    select 1
    from public.assessment_results ar
    join public.assessments a on a.id = ar.assessment_id
    join public.course_offerings co on co.id = a.course_offering_id
    where ar.id = assessment_result_history.assessment_result_id
      and (select private.has_permission('assessment.read', co.school_id))
  )
);

revoke insert, update, delete on public.assessment_result_history from authenticated;
grant select on public.assessment_result_history to authenticated;

-- Future public tables must not become reachable merely because a migration
-- created them. Each migration must grant only what its RLS contract needs.
alter default privileges in schema public revoke all on tables from anon, authenticated;

-- Tables created after the original authorization migration need explicit
-- Data API grants. RLS still decides which rows are visible/modifiable.
grant select, insert, update on public.fee_types to authenticated;
grant select, insert, update on public.fee_plans to authenticated;
grant select, insert, update on public.fee_plan_items to authenticated;
grant select, insert, update on public.student_services to authenticated;
grant select, insert, update on public.transport_services to authenticated;
grant select, insert, update on public.charges to authenticated;
grant select, insert, update on public.payments to authenticated;
grant select, insert, update on public.payment_allocations to authenticated;
grant select, insert, update on public.charge_adjustments to authenticated;
grant select, insert, update on public.payment_reversals to authenticated;
grant select, insert, update on public.receipts to authenticated;

grant select, insert, update on public.school_calendar_days to authenticated;
grant select, insert, update on public.rooms to authenticated;
grant select, insert, update on public.schedule_periods to authenticated;
grant select, insert, update on public.schedule_entries to authenticated;
grant select, insert, update on public.class_sessions to authenticated;
grant select, insert, update on public.attendance_records to authenticated;

grant select on public.audit_events to authenticated;

create or replace function private.capture_published_result_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_revision integer;
begin
  if old.status = 'PUBLISHED' then
    if nullif(trim(new.correction_reason), '') is null then
      raise exception 'A published assessment result requires a correction reason';
    end if;

    select coalesce(max(revision_no), 0) + 1
      into next_revision
    from public.assessment_result_history
    where assessment_result_id = old.id;

    insert into public.assessment_result_history (
      assessment_result_id,
      revision_no,
      raw_score,
      normalized_score,
      status,
      comment,
      entered_by,
      entered_at,
      published_at,
      published_by,
      correction_reason,
      captured_by
    )
    values (
      old.id,
      next_revision,
      old.raw_score,
      old.normalized_score,
      old.status,
      old.comment,
      old.entered_by,
      old.entered_at,
      old.published_at,
      old.published_by,
      new.correction_reason,
      (select auth.uid())
    );
  end if;

  return new;
end;
$$;

create trigger trg_capture_published_result_revision
before update on public.assessment_results
for each row execute function private.capture_published_result_revision();

revoke all on function private.validate_class_group_context() from public;
revoke all on function private.validate_enrollment_context() from public;
revoke all on function private.validate_class_placement_context() from public;
revoke all on function private.validate_curriculum_context() from public;
revoke all on function private.validate_course_offering_context() from public;
revoke all on function private.validate_teacher_assignment_context() from public;
revoke all on function private.validate_student_course_participation_context() from public;
revoke all on function private.validate_assessment_period_context() from public;
revoke all on function private.validate_assessment_context() from public;
revoke all on function private.validate_assessment_result_context() from public;
revoke all on function private.capture_published_result_revision() from public;
