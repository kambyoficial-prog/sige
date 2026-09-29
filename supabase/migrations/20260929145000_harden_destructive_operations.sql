-- SIGE 0007 — Prevent destructive client operations

revoke delete on public.people from authenticated;
revoke delete on public.students from authenticated;
revoke delete on public.student_identifiers from authenticated;
revoke delete on public.guardians from authenticated;
revoke delete on public.student_guardians from authenticated;
revoke delete on public.teachers from authenticated;
revoke delete on public.staff_members from authenticated;
revoke delete on public.employments from authenticated;
revoke delete on public.app_accounts from authenticated;
revoke delete on public.account_roles from authenticated;
revoke delete on public.class_groups from authenticated;
revoke delete on public.student_enrollments from authenticated;
revoke delete on public.class_placements from authenticated;
revoke delete on public.course_offerings from authenticated;
revoke delete on public.teacher_assignments from authenticated;
revoke delete on public.student_course_participations from authenticated;
revoke delete on public.assessment_periods from authenticated;
revoke delete on public.assessments from authenticated;
revoke delete on public.assessment_results from authenticated;
revoke delete on public.grade_rule_versions from authenticated;
revoke delete on public.charges from authenticated;
revoke delete on public.payments from authenticated;
revoke delete on public.payment_allocations from authenticated;
revoke delete on public.charge_adjustments from authenticated;
revoke delete on public.payment_reversals from authenticated;
revoke delete on public.receipts from authenticated;
revoke delete on public.audit_events from authenticated;

comment on schema private is
  'Non-Data-API authorization helpers and privileged internal functions.';
