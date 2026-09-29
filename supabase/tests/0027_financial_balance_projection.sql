-- SIGE 0044 regression
begin;
select plan(4);

select ok(exists(select 1 from pg_views where schemaname='public' and viewname='student_financial_balances'),'financial balance projection exists');
select ok(position('academic_year_id' in pg_get_viewdef('public.student_financial_balances'::regclass, true)) > 0,'financial balance preserves academic year');
select ok(position('group by ct.school_id, ct.student_id, ct.academic_year_id' in lower(pg_get_viewdef('public.student_financial_balances'::regclass, true))) > 0,'financial balance aggregates by year');
select ok(position('security_invoker' in lower((select pg_get_viewdef('public.student_financial_balances'::regclass, true)))) > 0,'financial projection uses invoker security');

select * from finish();
rollback;