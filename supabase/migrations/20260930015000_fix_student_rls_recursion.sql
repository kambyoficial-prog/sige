create or replace function private.teacher_has_student_access(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.students s
    join public.class_placements cp
      on cp.enrollment_id in (
        select e.id
        from public.student_enrollments e
        where e.student_id = s.id
      )
     and cp.status = 'ACTIVE'
    join public.course_offerings co
      on co.class_group_id = cp.class_group_id
    join public.teacher_assignments ta
      on ta.course_offering_id = co.id
     and ta.active
    join public.teachers t
      on t.id = ta.teacher_id
    where s.id = p_student_id
      and t.person_id = private.current_person_id()
      and private.has_permission('attendance.own.manage', s.school_id)
  );
$function$;

create or replace function private.can_read_student_enrollment(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.students s
    where s.id = p_student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
      )
  )
  or private.teacher_has_student_access(p_student_id);
$function$;

drop policy if exists enrollments_read on public.student_enrollments;
create policy enrollments_read
on public.student_enrollments
as permissive
for select
to authenticated
using (private.can_read_student_enrollment(student_id));

drop policy if exists teacher_enrollments_own_classes_read on public.student_enrollments;

drop policy if exists teacher_students_own_classes_read on public.students;
create policy teacher_students_own_classes_read
on public.students
as permissive
for select
to authenticated
using (private.teacher_has_student_access(id));

drop policy if exists teacher_people_own_classes_read on public.people;
create policy teacher_people_own_classes_read
on public.people
as permissive
for select
to authenticated
using (
  exists (
    select 1
    from public.students s
    where s.person_id = public.people.id
      and private.teacher_has_student_access(s.id)
  )
);