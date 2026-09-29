drop view if exists public.finance_balance_directory;
create view public.finance_balance_directory with(security_invoker=true) as
select b.school_id,b.student_id,pe.full_name student_name,b.academic_year_id,ay.label academic_year,b.charged_amount,b.paid_amount,b.balance_amount
from public.student_financial_balances b
join public.students s on s.id=b.student_id
join public.people pe on pe.id=s.person_id
join public.academic_years ay on ay.id=b.academic_year_id;
grant select on public.finance_balance_directory to authenticated;