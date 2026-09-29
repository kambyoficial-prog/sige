-- SIGE 0012 — assessment rules and period initialization
begin;
select plan(11);
select has_table('public','grade_rule_versions','grade rule versions table exists');
select has_table('public','assessment_periods','assessment periods table exists');
select ok(exists(select 1 from public.grade_rule_versions where code='MZ-ES-2022-06-30'),'MZ-ES-2022 rule is registered');
select ok(exists(select 1 from public.grade_rule_versions where code='MZ-ES-2022-06-30' and definition @> '{"trimester":{"acs_minimum":2,"at_count":1}}'::jsonb),'trimester minimum is stored');
select ok(exists(select 1 from public.grade_rule_versions where code='MZ-ES-2022-06-30' and definition @> '{"frequency":{"trimester_count":3}}'::jsonb),'frequency has three trimesters');
select ok(exists(select 1 from pg_proc where proname='initialize_assessment_periods'),'period initialization command exists');
select ok(exists(select 1 from pg_proc where proname='calculate_trimester_result'),'trimester calculation command exists');
select ok(exists(select 1 from pg_proc where proname='calculate_frequency_result'),'frequency calculation command exists');
select ok(exists(select 1 from pg_proc where proname='calculate_final_result'),'final calculation command exists');
select ok(exists(select 1 from pg_indexes where indexname='curriculum_areas_scope_uidx'),'curriculum area uniqueness is NULL-safe');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='assessment_periods' and policyname='assessment_periods_read'),'assessment periods have read policy');
select * from finish();
rollback;
