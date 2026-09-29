-- SIGE 0020 — Enrollment episodes instead of one-row-per-year enrollment
--
-- A student may withdraw/transfer out and later re-enroll in the same school
-- year. The enrollment record therefore represents an enrollment episode,
-- not merely a year flag. This preserves entry/exit history.

alter table public.student_enrollments
  add column if not exists enrollment_sequence integer;

update public.student_enrollments
set enrollment_sequence = 1
where enrollment_sequence is null;

alter table public.student_enrollments
  alter column enrollment_sequence set not null;

alter table public.student_enrollments
  drop constraint if exists student_enrollments_sequence_ck;

alter table public.student_enrollments
  add constraint student_enrollments_sequence_ck
  check (enrollment_sequence > 0);

alter table public.student_enrollments
  drop constraint if exists student_enrollments_student_id_academic_year_id_key;
alter table public.student_enrollments
  drop constraint if exists student_enrollments_student_id_academic_year_id_enrollment__key;

-- The foundation already owns this uniqueness as a table constraint.
-- Do not create a second identical unique index here.

alter table public.student_enrollments
  add constraint student_enrollments_no_temporal_overlap
  exclude using gist (
    student_id with =,
    daterange(
      enrolled_on,
      coalesce(exited_on + 1, '9999-12-31'::date),
      '[)'
    ) with &&
  )
  where (status <> 'CANCELLED');

create index student_enrollments_student_year_idx
  on public.student_enrollments (student_id, academic_year_id, enrolled_on desc);

comment on column public.student_enrollments.enrollment_sequence is
  'Sequential enrollment episode within a student and academic year. Allows withdrawal/transfer followed by re-enrollment without deleting history.';
