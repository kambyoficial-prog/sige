-- SIGE 0013 — regression: trimester calculations consume published source assessments
begin;

select plan(3);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_get_functiondef(p.oid) d on true
    where p.proname = 'calculate_trimester_result'
      and d like '%ar.status = ''PUBLISHED''%'
  ),
  'trimester calculation uses published assessment results'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_get_functiondef(p.oid) d on true
    where p.proname = 'calculate_trimester_result'
      and d like '%ar.status = ''ENTERED''%'
  ),
  'trimester calculation does not require unpublished entered results'
);

select ok(
  exists (
    select 1
    from public.grade_rule_versions
    where code = 'MZ-ES-2022-06-30'
      and definition @> '{"recovery":{"implemented":false}}'::jsonb
  ),
  'recovery remains explicitly unimplemented until a normative rule is verified'
);

select * from finish();
rollback;
