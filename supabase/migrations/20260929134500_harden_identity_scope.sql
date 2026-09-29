-- SIGE 0004 — Harden teacher scoping and account identity policies

create or replace function private.current_person_id()
returns uuid
language sql stable security definer
set search_path = public, auth, pg_temp
as $$
  select aa.person_id from public.app_accounts aa
  where aa.auth_user_id = (select auth.uid()) and aa.status = 'ACTIVE'
  limit 1;
$$;

revoke all on function private.current_person_id() from public;
grant execute on function private.current_person_id() to authenticated;

drop policy offerings_read on public.course_offerings;
create policy offerings_read on public.course_offerings for select to authenticated
using (
  (select private.has_permission('academic.read', school_id))
  or exists (
    select 1 from public.teacher_assignments ta
    join public.teachers t on t.id = ta.teacher_id
    where ta.course_offering_id = course_offerings.id
      and t.person_id = (select private.current_person_id())
      and ta.active and ta.starts_on <= current_date
      and (ta.ends_on is null or ta.ends_on >= current_date)
  )
);

drop policy assignments_read on public.teacher_assignments;
create policy assignments_read on public.teacher_assignments for select to authenticated
using (
  (select private.has_permission('academic.read'))
  or exists (
    select 1 from public.teachers t
    where t.id = teacher_assignments.teacher_id
      and t.person_id = (select private.current_person_id())
  )
);

drop policy assessments_read on public.assessments;
create policy assessments_read on public.assessments for select to authenticated
using (
  exists (
    select 1 from public.course_offerings co
    where co.id = assessments.course_offering_id
      and (
        (select private.has_permission('assessment.read', co.school_id))
        or (
          (select private.has_permission('assessment.own.read', co.school_id))
          and exists (
            select 1 from public.teacher_assignments ta
            join public.teachers t on t.id = ta.teacher_id
            where ta.course_offering_id = co.id
              and t.person_id = (select private.current_person_id())
              and ta.active and ta.starts_on <= current_date
              and (ta.ends_on is null or ta.ends_on >= current_date)
          )
        )
      )
  )
);

drop policy assessment_results_read on public.assessment_results;
create policy assessment_results_read on public.assessment_results for select to authenticated
using (
  exists (
    select 1
    from public.assessments a
    join public.course_offerings co on co.id = a.course_offering_id
    where a.id = assessment_results.assessment_id
      and (
        (select private.has_permission('assessment.read', co.school_id))
        or (
          (select private.has_permission('assessment.own.read', co.school_id))
          and exists (
            select 1 from public.teacher_assignments ta
            join public.teachers t on t.id = ta.teacher_id
            where ta.course_offering_id = co.id
              and t.person_id = (select private.current_person_id())
              and ta.active and ta.starts_on <= current_date
              and (ta.ends_on is null or ta.ends_on >= current_date)
          )
        )
      )
  )
);

drop policy assessment_results_manage on public.assessment_results;
create policy assessment_results_manage on public.assessment_results for all to authenticated
using (
  exists (
    select 1 from public.assessments a
    join public.course_offerings co on co.id = a.course_offering_id
    where a.id = assessment_results.assessment_id
      and (
        (select private.has_permission('assessment.manage', co.school_id))
        or (
          (select private.has_permission('assessment.own.enter', co.school_id))
          and exists (
            select 1 from public.teacher_assignments ta
            join public.teachers t on t.id = ta.teacher_id
            where ta.course_offering_id = co.id
              and t.person_id = (select private.current_person_id())
              and ta.active and ta.starts_on <= current_date
              and (ta.ends_on is null or ta.ends_on >= current_date)
          )
        )
      )
  )
)
with check (
  exists (
    select 1 from public.assessments a
    join public.course_offerings co on co.id = a.course_offering_id
    where a.id = assessment_results.assessment_id
      and (
        (select private.has_permission('assessment.manage', co.school_id))
        or (
          (select private.has_permission('assessment.own.enter', co.school_id))
          and exists (
            select 1 from public.teacher_assignments ta
            join public.teachers t on t.id = ta.teacher_id
            where ta.course_offering_id = co.id
              and t.person_id = (select private.current_person_id())
              and ta.active and ta.starts_on <= current_date
              and (ta.ends_on is null or ta.ends_on >= current_date)
          )
        )
      )
  )
);
