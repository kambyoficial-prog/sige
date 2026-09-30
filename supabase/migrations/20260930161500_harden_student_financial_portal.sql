-- SIGE — harden student financial portal
-- Returns only the authenticated student's current academic-year financial data
-- and school-configured payment instructions.
-- The function is SECURITY DEFINER but exposes no write capability.

create or replace function public.get_student_financial_portal()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  actor uuid := (select auth.uid());
  v_person_id uuid; v_student_id uuid; v_school_id uuid; v_year_id uuid; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select aa.person_id into v_person_id from public.app_accounts aa where aa.auth_user_id=actor and aa.active;
  select s.id,s.school_id into v_student_id,v_school_id from public.students s
    where s.person_id=v_person_id and s.status='ACTIVE' order by s.created_at desc limit 1;
  if v_student_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  select ay.id into v_year_id from public.academic_years ay
    where ay.school_id=v_school_id and ay.status='OPEN' order by ay.starts_on desc limit 1;

  select jsonb_build_object(
    'academic_year_id',v_year_id,
    'academic_year',(select jsonb_build_object('id',ay.id,'label',ay.label,'starts_on',ay.starts_on,'ends_on',ay.ends_on) from public.academic_years ay where ay.id=v_year_id),
    'charges',coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'fee_type_id',c.fee_type_id,'fee_type',ft.name,'description',c.description,'amount',c.amount,'due_on',c.due_on,'status',c.status,
      'paid_amount',coalesce((select sum(pa.amount) from public.payment_allocations pa join public.payments p on p.id=pa.payment_id where pa.charge_id=c.id and p.status='CONFIRMED'),0),
      'remaining_amount',greatest(c.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa join public.payments p on p.id=pa.payment_id where pa.charge_id=c.id and p.status='CONFIRMED'),0),0)
    ) order by c.due_on,c.created_at) from public.charges c left join public.fee_types ft on ft.id=c.fee_type_id where c.student_id=v_student_id and c.academic_year_id=v_year_id),'[]'::jsonb),
    'payment_instructions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'label',i.label,'bank_name',i.bank_name,'account_name',i.account_name,'account_number',i.account_number,'nib',i.nib,'iban',i.iban,'branch',i.branch,'payment_reference_template',i.payment_reference_template,'instructions',i.instructions
    ) order by i.created_at desc) from public.school_payment_instructions i where i.school_id=v_school_id and i.active and (i.academic_year_id is null or i.academic_year_id=v_year_id)),'[]'::jsonb),
    'payments',coalesce((select jsonb_agg(jsonb_build_object(
      'id',p.id,'amount',p.amount,'method',p.method,'status',p.status,'paid_at',p.paid_at,'confirmed_at',p.confirmed_at,'external_reference',p.external_reference,
      'receipt_number',(select r.receipt_number from public.receipts r where r.payment_id=p.id limit 1)
    ) order by p.paid_at desc) from public.payments p where p.student_id=v_student_id and p.school_id=v_school_id),'[]'::jsonb)
  ) into result;
  return result;
end $$;

revoke all on function public.get_student_financial_portal() from public;
grant execute on function public.get_student_financial_portal() to authenticated;
