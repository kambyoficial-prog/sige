-- SIGE 0023 — Default-deny function exposure
--
-- Database functions are Data API objects too. New public functions should be
-- opt-in, just like tables.

alter default privileges in schema public
  revoke execute on functions from anon, authenticated;

revoke all on all functions in schema public from anon;

-- Re-grant only the commands intentionally exposed to authenticated callers.
grant execute on function public.enroll_student(
  uuid, uuid, uuid, public.enrollment_entry_type, date, text, text
) to authenticated;

grant execute on function public.place_student_in_class(
  uuid, uuid, date, date, text, text, text
) to authenticated;

grant execute on function public.record_payment(
  uuid, numeric, public.payment_method, timestamptz, text, text, text, text
) to authenticated;

grant execute on function public.confirm_payment(uuid, text, text) to authenticated;
grant execute on function public.allocate_payment(uuid, uuid, numeric, text, text) to authenticated;

grant execute on function public.create_assessment(
  uuid, uuid, public.assessment_type, text, date, numeric, numeric, text, text
) to authenticated;

grant execute on function public.save_assessment_result(
  uuid, uuid, numeric, public.assessment_result_status, text, text, text
) to authenticated;

grant execute on function public.publish_assessment(uuid, text, text) to authenticated;

grant execute on function public.correct_published_result(
  uuid, numeric, public.assessment_result_status, text, text, text, text
) to authenticated;

grant execute on function public.open_academic_year(uuid, text, text) to authenticated;
grant execute on function public.close_academic_year(uuid, date, text, text, text) to authenticated;
