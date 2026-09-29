
create policy exam_sessions_read
on public.exam_sessions
for select to authenticated
using (
  private.has_permission('assessment.read',school_id)
  or private.has_permission('assessment.manage',school_id)
);

create policy exam_registrations_read
on public.exam_registrations
for select to authenticated
using (
  exists (
    select 1 from public.exam_sessions es
    where es.id=exam_registrations.exam_session_id
      and (
        private.has_permission('assessment.read',es.school_id)
        or private.has_permission('assessment.manage',es.school_id)
      )
  )
);

create policy exam_reviews_read
on public.exam_reviews
for select to authenticated
using (
  exists (
    select 1
    from public.assessment_results ar
    join public.assessments a on a.id=ar.assessment_id
    join public.course_offerings co on co.id=a.course_offering_id
    where ar.id=exam_reviews.assessment_result_id
      and (
        private.has_permission('assessment.read',co.school_id)
        or private.has_permission('assessment.manage',co.school_id)
      )
  )
);

create policy cycle_outcomes_read
on public.cycle_outcomes
for select to authenticated
using (
  private.has_permission('assessment.read',school_id)
  or private.has_permission('assessment.manage',school_id)
);
