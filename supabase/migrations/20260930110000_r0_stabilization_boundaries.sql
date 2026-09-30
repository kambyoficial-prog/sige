-- SIGE R0 — stabilization of authorization/read boundaries.
-- Fixes verified production failures without weakening RLS.

grant select on public.student_registrations to authenticated;

create or replace function private.teacher_has_student_access(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_course_participations scp
    join public.teacher_assignments ta
      on ta.course_offering_id = scp.course_offering_id
     and ta.active
     and ta.starts_on <= current_date
     and (ta.ends_on is null or ta.ends_on >= current_date)
    join public.teachers t
      on t.id = ta.teacher_id
    where scp.student_id = p_student_id
      and t.person_id = private.current_person_id()
  );
$$;

revoke all on function private.teacher_has_student_access(uuid) from public;
grant execute on function private.teacher_has_student_access(uuid) to authenticated;

drop policy if exists enrollments_read on public.student_enrollments;

create policy enrollments_read
on public.student_enrollments
for select to authenticated
using (
  private.has_permission(
    'enrollment.read',
    (select s.school_id from public.students s where s.id = student_enrollments.student_id)
  )
  or private.has_permission(
    'enrollment.manage',
    (select s.school_id from public.students s where s.id = student_enrollments.student_id)
  )
  or student_enrollments.student_id = private.current_student_id()
  or private.teacher_has_student_access(student_enrollments.student_id)
);

comment on function private.teacher_has_student_access(uuid)
is 'Returns whether the authenticated teacher is assigned to an active course offering attended by the student. Uses student_course_participations and does not query student_enrollments, preventing RLS recursion.';
