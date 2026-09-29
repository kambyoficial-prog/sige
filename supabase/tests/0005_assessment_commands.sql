begin;

select plan(14);

select ok(has_function('public','create_assessment',array['uuid','uuid','public.assessment_type','text','date','numeric','numeric','text','text']),
  'create_assessment exists');

select ok(has_function('public','save_assessment_result',array['uuid','uuid','numeric','public.assessment_result_status','text','text','text']),
  'save_assessment_result exists');

select ok(has_function('public','publish_assessment',array['uuid','text','text']),
  'publish_assessment exists');

select ok(has_function('public','correct_published_result',array['uuid','numeric','public.assessment_result_status','text','text','text','text']),
  'correct_published_result exists');

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='assessment_results'
      and grantee='authenticated' and privilege_type='INSERT'
  ),
  'authenticated cannot insert assessment results directly'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='assessment_results'
      and grantee='authenticated' and privilege_type='UPDATE'
  ),
  'authenticated cannot update assessment results directly'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='assessments'
      and grantee='authenticated' and privilege_type='INSERT'
  ),
  'authenticated cannot insert assessments directly'
);

select ok(
  exists (
    select 1 from information_schema.routine_privileges
    where routine_schema='public' and routine_name='correct_published_result'
      and grantee='authenticated' and privilege_type='EXECUTE'
  ),
  'authenticated can execute correction command'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_capture_published_result_revision'),
  'published result history trigger remains installed'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='assessment_result_history' and c.relrowsecurity
  ),
  'result history remains protected by RLS'
);

select ok(
  exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='assessment_result_history'
      and grantee='authenticated' and privilege_type='SELECT'
  ),
  'authenticated can read result history subject to RLS'
);

select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='publish_assessment'
  ),
  'publication command is database-backed'
);

select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='save_assessment_result'
  ),
  'result entry command is database-backed'
);

select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_assessment'
  ),
  'assessment creation command is database-backed'
);

select * from finish();
rollback;
