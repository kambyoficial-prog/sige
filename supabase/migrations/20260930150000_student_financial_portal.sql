-- Student financial portal and school-configured payment instructions.
create table if not exists public.school_payment_instructions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id),
  label text not null,
  bank_name text,
  account_name text,
  account_number text,
  nib text,
  iban text,
  branch text,
  payment_reference_template text,
  instructions text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.school_payment_instructions enable row level security;

create index if not exists school_payment_instructions_scope_idx
  on public.school_payment_instructions(school_id, academic_year_id, active);

create or replace function public.get_student_financial_portal()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := (select auth.uid());
  person_id uuid;
  student_id uuid;
  school_id uuid;
  year_id uuid;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select aa.person_id into person_id from public.app_accounts aa
  where aa.auth_user_id=actor and aa.active;
  select s.id,s.school_id into student_id,school_id from public.students s
  where s.person_id=person_id and s.status='ACTIVE' order by s.created_at desc limit 1;
  if student_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  select id into year_id from public.academic_years
  where school_id=school_id and status='OPEN' order by starts_on desc limit 1;
  select jsonb_build_object(
    'academic_year_id',year_id,
    'charges',coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'fee_type_id',c.fee_type_id,'fee_type',ft.name,'description',c.description,
      'amount',c.amount,'due_on',c.due_on,'status',c.status,
      'paid_amount',coalesce((select sum(pa.amount) from public.payment_allocations pa join public.payments p on p.id=pa.payment_id where pa.charge_id=c.id and p.status='CONFIRMED'),0)
    ) order by c.due_on,c.created_at) from public.charges c left join public.fee_types ft on ft.id=c.fee_type_id
      where c.student_id=student_id and c.academic_year_id=year_id),'[]'::jsonb),
    'payment_instructions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'label',i.label,'bank_name',i.bank_name,'account_name',i.account_name,
      'account_number',i.account_number,'nib',i.nib,'iban',i.iban,'branch',i.branch,
      'payment_reference_template',i.payment_reference_template,'instructions',i.instructions
    ) order by i.created_at desc) from public.school_payment_instructions i
      where i.school_id=school_id and i.active and (i.academic_year_id is null or i.academic_year_id=year_id)),'[]'::jsonb),
    'payments',coalesce((select jsonb_agg(jsonb_build_object(
      'id',p.id,'amount',p.amount,'method',p.method,'status',p.status,'paid_at',p.paid_at,
      'confirmed_at',p.confirmed_at,'external_reference',p.external_reference,'receipt_number',r.receipt_number
    ) order by p.paid_at desc) from public.payments p left join public.receipts r on r.payment_id=p.id
      where p.student_id=student_id),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

revoke all on function public.get_student_financial_portal() from public;
grant execute on function public.get_student_financial_portal() to authenticated;

create policy school_payment_instructions_manage
on public.school_payment_instructions for all to authenticated
using (private.has_permission('finance.manage', school_id))
with check (private.has_permission('finance.manage', school_id));

create policy school_payment_instructions_student_read
on public.school_payment_instructions for select to authenticated
using (
  active and exists (
    select 1 from public.students s
    join public.app_accounts aa on aa.person_id=s.person_id and aa.auth_user_id=auth.uid() and aa.active
    where s.school_id=school_payment_instructions.school_id and s.status='ACTIVE'
  )
);
