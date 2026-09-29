-- SIGE 0036 — one open academic year per school
--
-- Multiple future DRAFT years are allowed. Only one operational year may be OPEN.

create unique index if not exists academic_years_one_open_per_school_uidx
  on public.academic_years (school_id)
  where status = 'OPEN';

comment on index public.academic_years_one_open_per_school_uidx is
  'At most one OPEN academic year per school; historical and future DRAFT years remain allowed.';
