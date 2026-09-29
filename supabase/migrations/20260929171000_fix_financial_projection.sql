-- SIGE 0017 — Correct financial projection and allocation math
--
-- The previous balance projection joined charges directly to allocations.
-- A charge with N allocations could therefore have its base amount counted N
-- times. The corrected projection aggregates each charge first.

create or replace function private.charge_effective_amount(target_charge uuid)
returns numeric(12,2)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select greatest(
    0::numeric,
    c.amount + coalesce((
      select sum(
        case
          when ca.type in ('DISCOUNT','WAIVER','REVERSAL') then -ca.amount
          when ca.type in ('SURCHARGE','CORRECTION') then ca.amount
          else 0
        end
      )
      from public.charge_adjustments ca
      where ca.charge_id = c.id
    ), 0)
  )
  from public.charges c
  where c.id = target_charge;
$$;

create or replace view public.student_financial_balances
with (security_invoker = true)
as
with charge_totals as (
  select
    c.id,
    c.school_id,
    c.student_id,
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
  coalesce(sum(
    case
      when ct.status in ('CANCELLED','WAIVED') then 0
      else ct.effective_amount
    end
  ), 0) as charged_amount,
  coalesce(sum(
    case
      when ct.status in ('CANCELLED','WAIVED') then 0
      else coalesce(pt.paid_amount, 0)
    end
  ), 0) as paid_amount,
  coalesce(sum(
    case
      when ct.status in ('CANCELLED','WAIVED') then 0
      else ct.effective_amount - coalesce(pt.paid_amount, 0)
    end
  ), 0) as balance_amount
from charge_totals ct
left join payment_totals pt on pt.charge_id = ct.id
group by ct.school_id, ct.student_id;

create or replace function private.validate_payment_allocation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  payment_total numeric(12,2);
  allocated_total numeric(12,2);
  payment_state public.payment_status;
  payment_student uuid;
  charge_total numeric(12,2);
  charge_allocated numeric(12,2);
  charge_student uuid;
begin
  select p.amount, p.status, p.student_id
    into payment_total, payment_state, payment_student
  from public.payments p
  where p.id = new.payment_id
  for update;

  if payment_total is null then
    raise exception 'Payment % does not exist', new.payment_id;
  end if;

  if payment_state <> 'CONFIRMED' then
    raise exception 'Only confirmed payments can be allocated';
  end if;

  select c.student_id
    into charge_student
  from public.charges c
  where c.id = new.charge_id
  for update;

  if charge_student is null then
    raise exception 'Charge % does not exist', new.charge_id;
  end if;

  if charge_student <> payment_student then
    raise exception 'Payment and charge belong to different students';
  end if;

  charge_total := private.charge_effective_amount(new.charge_id);

  if charge_total is null or charge_total <= 0 then
    raise exception 'Charge has no allocatable balance';
  end if;

  select coalesce(sum(pa.amount), 0)
    into allocated_total
  from public.payment_allocations pa
  where pa.payment_id = new.payment_id
    and pa.id <> coalesce(
      new.id,
      '00000000-0000-0000-0000-000000000000'::uuid
    );

  if allocated_total + new.amount > payment_total then
    raise exception 'Payment allocation exceeds payment amount';
  end if;

  select coalesce(sum(pa.amount), 0)
    into charge_allocated
  from public.payment_allocations pa
  join public.payments p on p.id = pa.payment_id
  where pa.charge_id = new.charge_id
    and pa.id <> coalesce(
      new.id,
      '00000000-0000-0000-0000-000000000000'::uuid
    )
    and p.status = 'CONFIRMED';

  if charge_allocated + new.amount > charge_total then
    raise exception 'Payment allocation exceeds charge balance';
  end if;

  return new;
end;
$$;

revoke all on function private.charge_effective_amount(uuid) from public;
revoke all on function private.validate_payment_allocation() from public;

comment on view public.student_financial_balances is
  'Derived receivables projection. Charge values are aggregated per charge before student totals are calculated.';
