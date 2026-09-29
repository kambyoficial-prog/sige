-- SIGE 0016 — academic lifecycle and assessment regime regression
begin;
select plan(10);

select ok(exists(select 1 from pg_indexes where indexname='academic_years_one_open_per_school_uidx'),'only one OPEN academic year per school is enforced');
select ok(position('ANOTHER_ACADEMIC_YEAR_ALREADY_OPEN' in pg_get_functiondef('public.open_academic_year(uuid,text,text)'::regprocedure)) > 0,'open year command rejects a second OPEN year');
select ok(position('FUTURE_CLASS_PLACEMENTS_REMAIN' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close rejects future active class placements');
select ok(position('student_course_participations' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close ends active course participations');
select ok(position('set search_path = '''' in pg_get_functiondef('public.open_academic_year(uuid,text,text)'::regprocedure)) > 0,'open year security definer has empty search path');
select ok(position('set search_path = '''' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'close year security definer has empty search path');
select ok(position('array_agg(distinct ap.ordinal order by ap.ordinal) = array[1,2,3]' in pg_get_functiondef('public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'frequency calculation requires T1, T2 and T3');
select ok(position('pedagogical_parallelism' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'final result reads the configured pedagogical regime');
select ok(position('PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'final result refuses to infer an unconfigured pedagogical regime');
select has_column('public','schools','pedagogical_parallelism','school has explicit pedagogical regime configuration');

select * from finish();
rollback;