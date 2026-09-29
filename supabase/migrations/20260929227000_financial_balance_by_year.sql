-- SIGE 0041 — financial balance projection by academic year
--
-- Charges are year-bound. The balance projection must preserve that context.

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
group by ct.school_id, ct.student_id, ct.academic_year_id;

grant select on public.student_financial_balances to authenticated;
