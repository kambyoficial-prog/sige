begin;

select plan(12);

select ok(
  has_function(
    'public',
    'enroll_student',
    array[
      'uuid','uuid','uuid','public.enrollment_entry_type','date','text','text'
    ]
  ),
  'enroll_student command exists'
);

select ok(
  has_function(
    'public',
    'place_student_in_class',
    array['uuid','uuid','date','date','text','text','text']
  ),
  'place_student_in_class command exists'
);

select ok(
  has_function(
    'public',
    'record_payment',
    array['uuid','numeric','public.payment_method','timestamptz','text','text','text','text']
  ),
  'record_payment command exists'
);

select ok(
  has_function('public','confirm_payment',array['uuid','text','text']),
  'confirm_payment command exists'
);

select ok(
  has_function('public','allocate_payment',array['uuid','uuid','numeric','text','text']),
  'allocate_payment command exists'
);

select ok(
  exists (
    select 1 from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='enroll_student'
      and grantee='authenticated'
      and privilege_type='EXECUTE'
  ),
  'authenticated can execute enrollment command'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='payments'
      and grantee='authenticated'
      and privilege_type='INSERT'
  ),
  'authenticated cannot insert payments directly'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='payments'
      and grantee='authenticated'
      and privilege_type='UPDATE'
  ),
  'authenticated cannot update payments directly'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='payment_allocations'
      and grantee='authenticated'
      and privilege_type='INSERT'
  ),
  'authenticated cannot insert allocations directly'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'
      and p.proname='charge_effective_amount'
  ),
  'effective charge amount function exists'
);

select ok(
  exists (
    select 1
    from pg_views
    where schemaname='public'
      and viewname='student_financial_balances'
  ),
  'student financial balance projection exists'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgname='trg_validate_payment_allocation'
  ),
  'payment allocation integrity trigger exists'
);

select * from finish();
rollback;
