begin;

select plan(10);

select ok(
  has_function('public','enroll_student',array['uuid','uuid','uuid','public.enrollment_entry_type','date','text','text']),
  'enrollment command remains callable as an explicit API function'
);

select ok(
  exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='enroll_student'
      and grantee='authenticated'
      and privilege_type='EXECUTE'
  ),
  'authenticated has explicit execute on enrollment command'
);

select ok(
  not exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='enroll_student'
      and grantee='anon'
      and privilege_type='EXECUTE'
  ),
  'anon cannot execute enrollment command'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='enroll_student'
      and coalesce(p.proconfig::text, '') like '%search_path=%'
  ),
  'enrollment command has an explicit function search path'
);

select ok(
  exists (
    select 1
    from pg_namespace n
    where n.nspname='private'
  ),
  'private schema exists'
);

select ok(
  exists (
    select 1 from information_schema.role_usage_grants
    where object_schema='private'
      and grantee='authenticated'
      and privilege_type='USAGE'
  ),
  'authenticated has only schema usage needed to call private helpers'
);

select ok(
  not exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='confirm_payment'
      and grantee='anon'
      and privilege_type='EXECUTE'
  ),
  'anon cannot execute payment command'
);

select ok(
  not exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='publish_assessment'
      and grantee='anon'
      and privilege_type='EXECUTE'
  ),
  'anon cannot execute publication command'
);

select ok(
  not exists (
    select 1
    from information_schema.routine_privileges
    where routine_schema='public'
      and routine_name='close_academic_year'
      and grantee='anon'
      and privilege_type='EXECUTE'
  ),
  'anon cannot execute academic year closure'
);

select * from finish();
rollback;
