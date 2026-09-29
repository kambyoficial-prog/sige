-- SIGE 0045 — Guardian and student identifier read policies
--
-- The foundation enabled RLS on these tables but intentionally did not grant
-- generic reads. F3 makes their read path explicit and school-scoped.

create policy guardians_read
on public.guardians
for select to authenticated
using (
  private.has_permission('enrollment.read', school_id)
  or private.has_permission('enrollment.manage', school_id)
);

create policy student_guardians_read
on public.student_guardians
for select to authenticated
using (
  exists (
    select 1
    from public.students s
    where s.id = student_guardians.student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
      )
  )
);

create policy student_identifiers_read
on public.student_identifiers
for select to authenticated
using (
  exists (
    select 1
    from public.students s
    where s.id = student_identifiers.student_id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
      )
  )
);
