begin;

select plan(14);

select ok(
  has_table('public','academic_results'),
  'academic result ledger exists'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname='public'
      and tablename='academic_results'
  ),
  'academic results have RLS policy'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema='public'
      and table_name='academic_results'
      and grantee='authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'authenticated cannot mutate academic result ledger directly'
);

select ok(
  exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='calculate_trimester_result'
      and grantee='authenticated'
      and privilege_type='EXECUTE'
  ),
  'authenticated can invoke result calculation command'
);

select ok(
  not exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='calculate_trimester_result'
      and grantee='anon'
      and privilege_type='EXECUTE'
  ),
  'anon cannot invoke result calculation command'
);

select ok(
  exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='homologate_academic_result'
      and grantee='authenticated'
      and privilege_type='EXECUTE'
  ),
  'authenticated can invoke homologation command'
);

select ok(
  exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='publish_academic_result'
      and grantee='authenticated'
      and privilege_type='EXECUTE'
  ),
  'authenticated can invoke academic result publication command'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='calculate_trimester_result'
      and coalesce(p.proconfig::text, '') like '%search_path=%'
  ),
  'result calculation command pins its search path'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    where t.relname='academic_results'
      and c.conname='academic_results_snapshot_object'
  ),
  'result snapshot is required to be a JSON object'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    where t.relname='academic_results'
      and c.conname='academic_results_value_range'
  ),
  'result value is constrained to the 0–20 scale'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    where t.relname='academic_results'
      and c.conname='academic_results_status_timestamps'
  ),
  'published and homologated states require timestamps'
);

select ok(
  exists (
    select 1
    from pg_type t
    where t.typname='academic_result_status'
  ),
  'academic result status is a domain state machine'
);

select ok(
  exists (
    select 1
    from pg_type t
    where t.typname='academic_result_type'
  ),
  'academic result types are explicit'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='publish_academic_result'
  ),
  'academic publication is an explicit command, not direct CRUD'
);

select * from finish();
rollback;
