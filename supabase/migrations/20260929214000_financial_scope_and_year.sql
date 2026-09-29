-- SIGE 0031 — financial temporal and scope integrity
--
-- Charges are annual obligations. Payments are transactions that may settle
-- obligations from one or more academic years, so the academic year belongs
-- to the charge, not the payment.

alter table public.charges
  add column if not exists academic_year_id uuid references public.academic_years(id) on delete restrict;

alter table public.charges
  alter column academic_year_id set not null;

create index if not exists charges_student_year_idx
  on public.charges (student_id, academic_year_id, status);

create index if not exists charges_school_year_idx
  on public.charges (school_id, academic_year_id, status);

create or replace function private.validate_financial_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_school uuid;
  year_school uuid;
  fee_school uuid;
  payment_school uuid;
  charge_school uuid;
  service_school uuid;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_table_name = 'charges' then
    select s.school_id into student_school
    from public.students s where s.id = new.student_id;

    select ay.school_id into year_school
    from public.academic_years ay where ay.id = new.academic_year_id;

    if student_school is null or year_school is null or student_school <> year_school or new.school_id <> student_school then
      raise exception 'CHARGE_SCHOOL_CONTEXT_MISMATCH';
    end if;

    if new.fee_type_id is not null then
      select ft.school_id into fee_school
      from public.fee_types ft where ft.id = new.fee_type_id;
      if fee_school is null or fee_school <> new.school_id then
        raise exception 'CHARGE_FEE_TYPE_SCHOOL_MISMATCH';
      end if;
    end if;

    return new;
  end if;

  if tg_table_name = 'student_services' then
    select s.school_id into student_school
    from public.students s where s.id = new.student_id;

    select ay.school_id into year_school
    from public.academic_years ay where ay.id = new.academic_year_id;

    if student_school is null or year_school is null or student_school <> year_school then
      raise exception 'STUDENT_SERVICE_YEAR_CONTEXT_MISMATCH';
    end if;

    if new.transport_service_id is not null then
      select ts.school_id into service_school
      from public.transport_services ts where ts.id = new.transport_service_id;
      if service_school is null or service_school <> student_school then
        raise exception 'TRANSPORT_SERVICE_SCHOOL_MISMATCH';
      end if;
    end if;

    return new;
  end if;

  if tg_table_name = 'payments' then
    select s.school_id into student_school
    from public.students s where s.id = new.student_id;

    if student_school is null or student_school <> new.school_id then
      raise exception 'PAYMENT_STUDENT_SCHOOL_MISMATCH';
    end if;

    return new;
  end if;

  if tg_table_name = 'payment_allocations' then
    select p.school_id into payment_school
    from public.payments p where p.id = new.payment_id;

    select c.school_id into charge_school
    from public.charges c where c.id = new.charge_id;

    if payment_school is null or charge_school is null or payment_school <> charge_school then
      raise exception 'PAYMENT_ALLOCATION_SCHOOL_MISMATCH';
    end if;

    return new;
  end if;

  if tg_table_name = 'payment_reversals' then
    if not exists (select 1 from public.payments p where p.id = new.payment_id) then
      raise exception 'PAYMENT_NOT_FOUND';
    end if;
    return new;
  end if;

  if tg_table_name = 'receipts' then
    select p.school_id into payment_school
    from public.payments p where p.id = new.payment_id;

    if payment_school is null or payment_school <> new.school_id then
      raise exception 'RECEIPT_PAYMENT_SCHOOL_MISMATCH';
    end if;

    return new;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_financial_scope() from public;

drop trigger if exists trg_validate_charge_financial_scope on public.charges;
create trigger trg_validate_charge_financial_scope
before insert or update on public.charges
for each row execute function private.validate_financial_scope();

drop trigger if exists trg_validate_student_service_financial_scope on public.student_services;
create trigger trg_validate_student_service_financial_scope
before insert or update on public.student_services
for each row execute function private.validate_financial_scope();

drop trigger if exists trg_validate_payment_financial_scope on public.payments;
create trigger trg_validate_payment_financial_scope
before insert or update on public.payments
for each row execute function private.validate_financial_scope();

drop trigger if exists trg_validate_payment_allocation_financial_scope on public.payment_allocations;
create trigger trg_validate_payment_allocation_financial_scope
before insert or update on public.payment_allocations
for each row execute function private.validate_financial_scope();

drop trigger if exists trg_validate_payment_reversal_financial_scope on public.payment_reversals;
create trigger trg_validate_payment_reversal_financial_scope
before insert or update on public.payment_reversals
for each row execute function private.validate_financial_scope();

drop trigger if exists trg_validate_receipt_financial_scope on public.receipts;
create trigger trg_validate_receipt_financial_scope
before insert or update on public.receipts
for each row execute function private.validate_financial_scope();

-- Attach the allocation math validator. It existed as a function but was not
-- previously attached to payment_allocations, leaving a direct mutation path
-- for SECURITY DEFINER commands.
drop trigger if exists trg_validate_payment_allocation_math on public.payment_allocations;
create trigger trg_validate_payment_allocation_math
before insert or update on public.payment_allocations
for each row execute function private.validate_payment_allocation();

-- Historical financial projections must be filterable by academic year.
drop view if exists public.student_financial_balances;
create view public.student_financial_balances
with (security_invoker = true)
as
with charge_totals as (
  select
    c.id,
    c.school_id,
    c.student_id,
    c.academic_year_id,
    c.status,
    c.due_on,
    private.charge_effective_amount(c.id) as effective_amount
  from public.charges c
),
payment_totals as (
  select
    pa.charge_id,
    coalesce(sum(
      case when p.status = 'CONFIRMED' then pa.amount else 0 end
    ), 0) as paid_amount
  from public.payment_allocations pa
  join public.payments p on p.id = pa.payment_id
  group by pa.charge_id
)
select
  ct.school_id,
  ct.student_id,
  ct.academic_year_id,
  coalesce(sum(
    case when ct.status in ('CANCELLED','WAIVED') then 0
         else ct.effective_amount end
  ), 0) as charged_amount,
  coalesce(sum(
    case when ct.status in ('CANCELLED','WAIVED') then 0
         else coalesce(pt.paid_amount,0) end
  ), 0) as paid_amount,
  coalesce(sum(
    case when ct.status in ('CANCELLED','WAIVED') then 0
         else ct.effective_amount - coalesce(pt.paid_amount,0) end
  ), 0) as balance_amount
from charge_totals ct
left join payment_totals pt on pt.charge_id = ct.id
group by ct.school_id, ct.student_id, ct.academic_year_id;

comment on column public.charges.academic_year_id is
  'Academic year that owns the receivable. Payments remain independent transactions and can be allocated to obligations from different years.';
