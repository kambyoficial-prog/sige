-- SIGE: role-scoped read boundaries for direction, secretariat, teachers and students.
-- This migration narrows read access by functional relationship while preserving
-- school-wide access for management roles.

create or replace function private.current_student_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.students s
  where s.person_id = private.current_person_id()
    and s.status = 'ACTIVE'
  limit 1;
$$;

create or replace function private.current_teacher_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select t.id
  from public.teachers t
  where t.person_id = private.current_person_id()
  limit 1;
$$;

create or replace function private.teacher_has_offering_access(p_course_offering_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_assignments ta
    join public.teachers t on t.id = ta.teacher_id
    where ta.course_offering_id = p_course_offering_id
      and ta.active
      and ta.starts_on <= current_date
      and (ta.ends_on is null or ta.ends_on >= current_date)
      and t.person_id = private.current_person_id()
  );
$$;

create or replace function private.student_has_offering_access(p_course_offering_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_course_participations scp
    where scp.course_offering_id = p_course_offering_id
      and scp.student_id = private.current_student_id()
  );
$$;

create or replace function private.student_has_class_access(p_class_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.class_placements cp
    join public.student_enrollments se on se.id = cp.enrollment_id
    where cp.class_group_id = p_class_group_id
      and cp.status = 'ACTIVE'
      and se.student_id = private.current_student_id()
  );
$$;

create or replace function private.teacher_has_class_access(p_class_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_assignments ta
    join public.course_offerings co on co.id = ta.course_offering_id
    join public.teachers t on t.id = ta.teacher_id
    where co.class_group_id = p_class_group_id
      and ta.active
      and ta.starts_on <= current_date
      and (ta.ends_on is null or ta.ends_on >= current_date)
      and t.person_id = private.current_person_id()
  );
$$;

create or replace function private.can_read_student_record(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.students s
    where s.id = p_student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
        or s.id = private.current_student_id()
        or private.teacher_has_student_access(s.id)
      )
  );
$$;

grant execute on function private.current_student_id() to authenticated;
grant execute on function private.current_teacher_id() to authenticated;
grant execute on function private.teacher_has_offering_access(uuid) to authenticated;
grant execute on function private.student_has_offering_access(uuid) to authenticated;
grant execute on function private.student_has_class_access(uuid) to authenticated;
grant execute on function private.teacher_has_class_access(uuid) to authenticated;
grant execute on function private.can_read_student_record(uuid) to authenticated;

revoke execute on function private.current_student_id() from anon;
revoke execute on function private.current_teacher_id() from anon;
revoke execute on function private.teacher_has_offering_access(uuid) from anon;
revoke execute on function private.student_has_offering_access(uuid) from anon;
revoke execute on function private.student_has_class_access(uuid) from anon;
revoke execute on function private.teacher_has_class_access(uuid) from anon;
revoke execute on function private.can_read_student_record(uuid) from anon;

drop policy if exists students_read on public.students;
create policy students_read on public.students
for select to authenticated
using (
  private.has_permission('enrollment.read', school_id)
  or private.has_permission('enrollment.manage', school_id)
  or id = private.current_student_id()
  or private.teacher_has_student_access(id)
);

drop policy if exists people_read on public.people;
create policy people_read on public.people
for select to authenticated
using (
  exists (
    select 1 from public.students s
    where s.person_id = people.id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
        or s.id = private.current_student_id()
        or private.teacher_has_student_access(s.id)
      )
  )
  or exists (
    select 1 from public.guardians g
    where g.person_id = people.id
      and private.has_permission('enrollment.read', g.school_id)
  )
  or exists (
    select 1 from public.teachers t
    where t.person_id = people.id
      and (
        private.has_permission('operations.read', t.school_id)
        or private.has_permission('assessment.read', t.school_id)
      )
      and (
        private.current_teacher_id() is null
        or t.id = private.current_teacher_id()
        or private.has_permission('teacher.manage', t.school_id)
      )
  )
  or exists (
    select 1 from public.staff_members sm
    where sm.person_id = people.id
      and private.has_permission('administration.manage', sm.school_id)
  )
  or exists (
    select 1 from public.app_accounts aa
    where aa.person_id = people.id
      and aa.auth_user_id = (select auth.uid())
  )
);

drop policy if exists student_guardians_read on public.student_guardians;
create policy student_guardians_read on public.student_guardians
for select to authenticated
using (
  exists (
    select 1 from public.students s
    where s.id = student_guardians.student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
        or s.id = private.current_student_id()
      )
  )
  or private.teacher_has_student_access(student_guardians.student_id)
);

drop policy if exists student_identifiers_read on public.student_identifiers;
create policy student_identifiers_read on public.student_identifiers
for select to authenticated
using (
  exists (
    select 1 from public.students s
    where s.id = student_identifiers.student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
        or s.id = private.current_student_id()
        or private.teacher_has_student_access(s.id)
      )
  )
);

drop policy if exists enrollments_read on public.student_enrollments;
create policy enrollments_read on public.student_enrollments
for select to authenticated
using (private.can_read_student_record(student_id));

drop policy if exists academic_ops_class_placements_read on public.class_placements;
drop policy if exists class_placements_read on public.class_placements;
create policy class_placements_read on public.class_placements
for select to authenticated
using (
  exists (
    select 1 from public.class_groups cg
    where cg.id = class_placements.class_group_id
      and (
        private.has_permission('enrollment.read', cg.school_id)
        or private.has_permission('operations.read', cg.school_id)
        or private.has_permission('operations.manage', cg.school_id)
        or private.has_permission('enrollment.manage', cg.school_id)
        or exists (
          select 1 from public.student_enrollments se
          where se.id = class_placements.enrollment_id
            and se.student_id = private.current_student_id()
        )
        or private.teacher_has_class_access(cg.id)
      )
  )
);

drop policy if exists academic_ops_class_groups_read on public.class_groups;
drop policy if exists class_groups_read on public.class_groups;
create policy class_groups_read on public.class_groups
for select to authenticated
using (
  private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
  or private.has_permission('enrollment.read', school_id)
  or private.has_permission('enrollment.manage', school_id)
  or private.student_has_class_access(id)
  or private.teacher_has_class_access(id)
);

drop policy if exists academic_ops_course_offerings_read on public.course_offerings;
drop policy if exists course_offerings_read on public.course_offerings;
create policy course_offerings_read on public.course_offerings
for select to authenticated
using (
  private.has_permission('operations.manage', school_id)
  or private.has_permission('enrollment.read', school_id)
  or private.has_permission('enrollment.manage', school_id)
  or private.has_permission('assessment.manage', school_id)
  or (
    private.has_permission('operations.read', school_id)
    and private.current_teacher_id() is null
    and private.current_student_id() is null
  )
  or private.teacher_has_offering_access(id)
  or private.student_has_offering_access(id)
);

drop policy if exists academic_ops_teacher_assignments_read on public.teacher_assignments;
drop policy if exists teacher_assignments_read on public.teacher_assignments;
create policy teacher_assignments_read on public.teacher_assignments
for select to authenticated
using (
  exists (
    select 1 from public.course_offerings co
    where co.id = teacher_assignments.course_offering_id
      and (
        private.has_permission('operations.manage', co.school_id)
        or private.has_permission('assessment.manage', co.school_id)
        or private.has_permission('enrollment.read', co.school_id)
        or (
          private.has_permission('operations.read', co.school_id)
          and private.current_teacher_id() is null
          and private.current_student_id() is null
        )
        or private.teacher_has_offering_access(co.id)
        or private.student_has_offering_access(co.id)
      )
  )
);

drop policy if exists academic_ops_student_course_participations_read on public.student_course_participations;
drop policy if exists student_course_participations_read on public.student_course_participations;
create policy student_course_participations_read on public.student_course_participations
for select to authenticated
using (
  exists (
    select 1 from public.course_offerings co
    where co.id = student_course_participations.course_offering_id
      and (
        private.has_permission('operations.manage', co.school_id)
        or private.has_permission('enrollment.read', co.school_id)
        or private.has_permission('assessment.manage', co.school_id)
        or (
          private.has_permission('operations.read', co.school_id)
          and private.current_teacher_id() is null
          and private.current_student_id() is null
        )
        or (
          private.teacher_has_offering_access(co.id)
          and private.has_permission('assessment.read', co.school_id)
        )
        or student_course_participations.student_id = private.current_student_id()
      )
  )
);

drop policy if exists assessment_definitions_read on public.assessment_definitions;
create policy assessment_definitions_read on public.assessment_definitions
for select to authenticated
using (
  private.has_permission('assessment.manage', school_id)
  or (
    private.has_permission('assessment.read', school_id)
    and (
      (
        private.current_teacher_id() is null
        and private.current_student_id() is null
      )
      or exists (
        select 1 from public.course_offerings co
        where co.id = assessment_definitions.course_offering_id
          and (
            private.teacher_has_offering_access(co.id)
            or private.student_has_offering_access(co.id)
          )
      )
    )
  )
);

drop policy if exists assessments_read on public.assessments;
create policy assessments_read on public.assessments
for select to authenticated
using (
  exists (
    select 1 from public.course_offerings co
    where co.id = assessments.course_offering_id
      and (
        private.has_permission('assessment.manage', co.school_id)
        or (
          private.has_permission('assessment.read', co.school_id)
          and (
            (private.current_teacher_id() is null and private.current_student_id() is null)
            or private.teacher_has_offering_access(co.id)
            or private.student_has_offering_access(co.id)
          )
        )
      )
  )
);

drop policy if exists assessment_results_read on public.assessment_results;
create policy assessment_results_read on public.assessment_results
for select to authenticated
using (
  exists (
    select 1
    from public.assessments a
    join public.course_offerings co on co.id = a.course_offering_id
    where a.id = assessment_results.assessment_id
      and (
        private.has_permission('assessment.manage', co.school_id)
        or (
          private.has_permission('assessment.read', co.school_id)
          and (
            (private.current_teacher_id() is null and private.current_student_id() is null)
            or private.teacher_has_offering_access(co.id)
            or assessment_results.student_id = private.current_student_id()
          )
        )
      )
  )
);

drop policy if exists academic_results_select on public.academic_results;
create policy academic_results_select on public.academic_results
for select to authenticated
using (
  private.has_permission('assessment.manage', school_id)
  or (
    private.has_permission('assessment.read', school_id)
    and (
      (private.current_teacher_id() is null and private.current_student_id() is null)
      or exists (
        select 1
        from public.course_offerings co
        where co.id = academic_results.course_offering_id
          and (
            private.teacher_has_offering_access(co.id)
            or academic_results.student_id = private.current_student_id()
          )
      )
    )
  )
);

drop policy if exists schedule_read on public.schedule_entries;
create policy schedule_read on public.schedule_entries
for select to authenticated
using (
  private.has_permission('operations.manage', school_id)
  or (
    private.has_permission('operations.read', school_id)
    and (
      (private.current_teacher_id() is null and private.current_student_id() is null)
      or exists (
        select 1
        from public.teacher_assignments ta
        join public.teachers t on t.id = ta.teacher_id
        where ta.id = schedule_entries.teacher_assignment_id
          and ta.active
          and (
            t.person_id = private.current_person_id()
            or private.student_has_offering_access(ta.course_offering_id)
          )
      )
    )
  )
);

drop policy if exists periods_read on public.schedule_periods;
create policy periods_read on public.schedule_periods
for select to authenticated
using (
  private.has_permission('operations.manage', school_id)
  or private.has_permission('operations.read', school_id)
);

comment on function private.current_student_id() is 'Returns the active student bound to the authenticated person, if any.';
comment on function private.current_teacher_id() is 'Returns the teacher bound to the authenticated person, if any.';
comment on function private.teacher_has_offering_access(uuid) is 'Returns whether the current teacher has an active assignment to the offering.';
comment on function private.student_has_offering_access(uuid) is 'Returns whether the current student participates in the offering.';
comment on function private.student_has_class_access(uuid) is 'Returns whether the current student is actively placed in the class.';
comment on function private.teacher_has_class_access(uuid) is 'Returns whether the current teacher teaches at least one active offering in the class.';
comment on function private.can_read_student_record(uuid) is 'Central read boundary for student records: management, own student, or assigned teacher.';
