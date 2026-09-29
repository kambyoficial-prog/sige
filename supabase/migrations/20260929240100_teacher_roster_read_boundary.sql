-- SIGE F5 — teacher-scoped roster read boundary
-- Teachers need roster names/enrollment rows for their own classes without
-- receiving school-wide enrollment access.

create policy teacher_students_own_classes_read
on public.students
for select to authenticated
using (
  exists (
    select 1
    from public.class_placements cp
    join public.student_enrollments e on e.id = cp.enrollment_id
    join public.course_offerings co
      on co.class_group_id = cp.class_group_id
     and co.academic_year_id = e.academic_year_id
    join public.teacher_assignments ta
      on ta.course_offering_id = co.id
     and ta.active
    join public.teachers t
      on t.id = ta.teacher_id
    where e.student_id = students.id
      and cp.status = 'ACTIVE'
      and t.person_id = (select private.current_person_id())
      and private.has_permission('attendance.own.manage', students.school_id)
  )
);

create policy teacher_enrollments_own_classes_read
on public.student_enrollments
for select to authenticated
using (
  exists (
    select 1
    from public.class_placements cp
    join public.course_offerings co
      on co.class_group_id = cp.class_group_id
     and co.academic_year_id = student_enrollments.academic_year_id
    join public.teacher_assignments ta
      on ta.course_offering_id = co.id
     and ta.active
    join public.teachers t
      on t.id = ta.teacher_id
    where cp.enrollment_id = student_enrollments.id
      and cp.status = 'ACTIVE'
      and t.person_id = (select private.current_person_id())
      and private.has_permission('attendance.own.manage', (
        select s.school_id from public.students s where s.id = student_enrollments.student_id
      ))
  )
);

create policy teacher_people_own_classes_read
on public.people
for select to authenticated
using (
  exists (
    select 1
    from public.students s
    join public.class_placements cp on cp.enrollment_id in (
      select e.id from public.student_enrollments e where e.student_id = s.id
    )
    join public.course_offerings co
      on co.class_group_id = cp.class_group_id
    join public.teacher_assignments ta
      on ta.course_offering_id = co.id
     and ta.active
    join public.teachers t on t.id = ta.teacher_id
    where s.person_id = people.id
      and cp.status = 'ACTIVE'
      and t.person_id = (select private.current_person_id())
      and private.has_permission('attendance.own.manage', s.school_id)
  )
);
