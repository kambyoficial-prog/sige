-- SIGE 0047 — Teacher profile read model

create or replace view public.teacher_profile
with (security_invoker = true)
as
select
  td.*,
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'course_offering_id', co.id,
        'class_group_id', cg.id,
        'class_name', coalesce(cg.name, cg.code),
        'subject_id', sub.id,
        'subject_name', sub.name,
        'subject_code', sub.code,
        'starts_on', ta.starts_on,
        'ends_on', ta.ends_on
      )
      order by ta.starts_on desc, cg.name, sub.name
    )
    from public.teacher_assignments ta
    join public.course_offerings co on co.id = ta.course_offering_id
    join public.class_groups cg on cg.id = co.class_group_id
    join public.subjects sub on sub.id = co.subject_id
    where ta.teacher_id = td.id
      and ta.active
  ), '[]'::jsonb) as assignments
from public.teacher_directory td;

grant select on public.teacher_profile to authenticated;
