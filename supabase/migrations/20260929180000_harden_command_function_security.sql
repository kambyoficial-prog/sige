-- SIGE 0022 — Security hardening for privileged functions
--
-- Supabase's current guidance recommends an explicitly pinned search_path for
-- SECURITY DEFINER functions. All new command functions use schema-qualified
-- application relations and can therefore run with an empty search_path.

grant usage on schema private to authenticated;

alter function private.begin_command(text, uuid, text, text)
  set search_path = '';

alter function private.complete_command(text, uuid, text, jsonb)
  set search_path = '';

alter function private.charge_effective_amount(uuid)
  set search_path = '';

alter function public.enroll_student(
  uuid, uuid, uuid, public.enrollment_entry_type, date, text, text
)
  set search_path = '';

alter function public.place_student_in_class(
  uuid, uuid, date, date, text, text, text
)
  set search_path = '';

alter function public.record_payment(
  uuid, numeric, public.payment_method, timestamptz, text, text, text, text
)
  set search_path = '';

alter function public.confirm_payment(uuid, text, text)
  set search_path = '';

alter function public.allocate_payment(uuid, uuid, numeric, text, text)
  set search_path = '';

alter function public.create_assessment(
  uuid, uuid, public.assessment_type, text, date, numeric, numeric, text, text
)
  set search_path = '';

alter function public.save_assessment_result(
  uuid, uuid, numeric, public.assessment_result_status, text, text, text
)
  set search_path = '';

alter function public.publish_assessment(uuid, text, text)
  set search_path = '';

alter function public.correct_published_result(
  uuid, numeric, public.assessment_result_status, text, text, text, text
)
  set search_path = '';

alter function public.open_academic_year(uuid, text, text)
  set search_path = '';

alter function public.close_academic_year(uuid, date, text, text, text)
  set search_path = '';
