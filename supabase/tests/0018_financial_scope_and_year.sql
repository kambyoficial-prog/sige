-- SIGE 0018 — financial scope and annual obligation regression
begin;
select plan(11);

select has_column('public','charges','academic_year_id','charges belong to an academic year');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_charge_financial_scope'),'charge financial scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_student_service_financial_scope'),'student service scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_payment_financial_scope'),'payment scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_payment_allocation_financial_scope'),'payment allocation scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_payment_allocation_math'),'payment allocation math validator is attached');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_receipt_financial_scope'),'receipt scope trigger exists');
select ok(exists(select 1 from pg_indexes where indexname='charges_student_year_idx'),'annual charge index exists');
select ok(position('academic_year_id' in pg_get_viewdef('public.student_financial_balances'::regclass)) > 0,'financial balance projection exposes academic year');
select ok(position('set search_path = '''' in pg_get_functiondef('private.charge_effective_amount(uuid)'::regprocedure)) > 0,'charge amount helper has empty search path');
select ok(position('set search_path = '''' in pg_get_functiondef('public.record_payment(uuid,numeric,public.payment_method,timestamptz,text,text,text,text)'::regprocedure)) > 0,'payment command has empty search path');
select * from finish();
rollback;