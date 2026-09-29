-- SIGE 0044 — Course offering directory for pedagogical operations

create or replace view public.course_offering_directory
with (security_invoker = true)
as
select
  co.id,
  co.school_id,
  co.academic_year_id,
  ay.label as academic_year_label,
  co.class_group_id,
  co.subject_id,
  s.name as subject_name,
  s.code as subject_code,
  co.curriculum_subject_id,
  co.status,
  teacher_assignment.teacher_id,
  teacher_assignment.teacher_name,
  teacher_assignment.starts_on as teacher_starts_on,
  teacher_assignment.ends_on as teacher_ends_on
from public.course_offerings co
join public.academic_years ay on ay.id = co.academic_year_id
join public.subjects s on s.id = co.subject_id
left join lateral (
  select
    ta.teacher_id,
    p.full_name as teacher_name,
    ta.starts_on,
    ta.ends_on
  from public.teacher_assignments ta
  join public.teachers t on t.id = ta.teacher_id
  join public.people p on p.id = t.person_id
  where ta.course_offering_id = co.id
    and ta.active
  order by ta.starts_on desc
  limit 1
) teacher_assignment on true;

grant select on public.course_offering_directory to authenticated;
