-- SIGE 0043 — Enriched student/class read models
-- Adds human-readable academic context to the student profile without moving
-- domain logic into the frontend.

create or replace view public.student_directory
with (security_invoker = true)
as
select
  s.id,
  s.school_id,
  s.school_number,
  s.status,
  s.admission_date,
  p.full_name,
  p.first_name,
  p.last_name,
  p.gender,
  p.birth_date,
  p.phone,
  p.email,
  p.address,
  current_enrollment.id as enrollment_id,
  current_enrollment.academic_year_id,
  current_enrollment.academic_year_label,
  current_enrollment.grade_level_id,
  current_enrollment.grade_level_name,
  current_enrollment.enrollment_status,
  current_enrollment.enrolled_on,
  current_class.class_group_id,
  current_class.class_name,
  current_class.section_code
from public.students s
join public.people p on p.id = s.person_id
left join lateral (
  select
    e.id,
    e.academic_year_id,
    ay.label as academic_year_label,
    e.grade_level_id,
    gl.name as grade_level_name,
    e.status as enrollment_status,
    e.enrolled_on
  from public.student_enrollments e
  join public.academic_years ay on ay.id = e.academic_year_id
  join public.grade_levels gl on gl.id = e.grade_level_id
  where e.student_id = s.id
    and e.status in ('PENDING','ACTIVE','TRANSFERRED_IN')
  order by e.enrolled_on desc, e.enrollment_sequence desc
  limit 1
) current_enrollment on true
left join lateral (
  select
    cp.class_group_id,
    coalesce(cg.name, cg.code, cg.id::text) as class_name,
    cg.section_code
  from public.class_placements cp
  join public.class_groups cg on cg.id = cp.class_group_id
  where cp.enrollment_id = current_enrollment.id
    and cp.status = 'ACTIVE'
  order by cp.starts_on desc
  limit 1
) current_class on true;

grant select on public.student_directory to authenticated;
