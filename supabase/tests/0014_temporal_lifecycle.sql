-- SIGE 0014 — temporal locking and historical access
begin;
select plan(9);

select has_column('public','assessment_periods','status','assessment periods have explicit lifecycle status');
select has_column('public','assessment_periods','closed_at','assessment periods record closure time');

select ok(exists(select 1 from pg_proc where proname='close_assessment_period'),'period close command exists');
select ok(exists(select 1 from pg_proc where proname='assert_academic_year_mutable'),'closed-year guard exists');

select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_assessments'),'assessment closed-year trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_assessment_results'),'assessment result closed-year trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_academic_results'),'academic result closed-year trigger exists');

select ok(exists(select 1 from pg_views where schemaname='public' and viewname='academic_year_history'),'year history view exists');
select ok(exists(select 1 from pg_views where schemaname='public' and viewname='assessment_period_history'),'period history view exists');

select * from finish();
rollback;
