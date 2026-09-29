-- SIGE 0021 — financial lifecycle regression
begin;
select plan(12);

select ok(exists(select 1 from pg_proc where proname='reverse_payment' and pronamespace='public'::regnamespace),'reverse payment command exists');
select ok(exists(select 1 from pg_proc where proname='issue_receipt' and pronamespace='public'::regnamespace),'receipt command exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_payment_allocation'),'payment allocation validator is attached');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_charge_temporal_scope'),'charge temporal guard exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_student_service_temporal_scope'),'student service temporal guard exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_fee_plan_scope'),'fee plan scope guard exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_fee_plan_item_scope'),'fee plan item scope guard exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_payment_reversal_scope'),'payment reversal scope guard exists');
select ok(position('PAYMENT_NOT_REVERSIBLE' in pg_get_functiondef('public.reverse_payment(uuid,text,text,text)'::regprocedure)) > 0,'reversal validates payment state');
select ok(position('status = ''REVERSED''' in pg_get_functiondef('public.reverse_payment(uuid,text,text,text)'::regprocedure)) > 0,'reversal changes payment state');
select ok(position('RECEIPT_REQUIRES_CONFIRMED_PAYMENT' in pg_get_functiondef('public.issue_receipt(uuid,text,text,text)'::regprocedure)) > 0,'receipt requires confirmed payment');
select ok(exists(
  select 1
  from information_schema.columns
  where table_schema='public' and table_name='charges' and column_name='academic_year_id'
),'charges are year-bound');
select * from finish();
rollback;