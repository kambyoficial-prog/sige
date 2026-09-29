-- F6 normative gradebook structural assertions
select ok(
  exists(select 1 from information_schema.columns
         where table_schema='public' and table_name='academic_years' and column_name='grade_rule_version_id'),
  'academic years bind a frozen grade rule'
);

select ok(
  exists(select 1 from public.grade_rule_versions where code='MZ-ESG-RGA-2019'),
  'verified 2019 ESG rule version exists'
);

select ok(
  exists(select 1 from information_schema.tables
         where table_schema='public' and table_name='assessment_definitions'),
  'assessment definitions exist'
);

select ok(
  exists(select 1 from pg_proc where proname='create_assessment_definition'),
  'assessment definition command exists'
);

select ok(
  exists(select 1 from pg_views where schemaname='public' and viewname='assessment_gradebook'),
  'gradebook read model exists'
);

select ok(
  exists(select 1 from pg_views where schemaname='public' and viewname='academic_result_pauta'),
  'published pauta read model exists'
);

select ok(
  position('grade_rule_version_id' in pg_get_functiondef(
    'public.calculate_trimester_result(uuid,uuid,uuid,text,text)'::regprocedure
  )) > 0,
  'trimester calculation reads year-bound rule version'
);

select ok(
  position('grade_rule_version_id' in pg_get_functiondef(
    'public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text)'::regprocedure
  )) > 0,
  'frequency calculation reads year-bound rule version'
);

select ok(
  position('10_AND_12' in pg_get_functiondef(
    'public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure
  )) > 0,
  'final calculation targets verified terminal exam classes'
);

select ok(
  position('assessment_definition' in pg_get_functiondef(
    'public.create_assessment(uuid,uuid,public.assessment_type,text,date,numeric,numeric,uuid,text,text)'::regprocedure
  )) > 0,
  'assessment creation can bind a configured definition'
);
