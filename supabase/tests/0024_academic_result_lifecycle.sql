-- SIGE 0038 — academic result lifecycle regression
begin;
select plan(12);

select ok(exists(select 1 from pg_proc where proname='homologate_academic_result' and pronamespace='public'::regnamespace),'academic result homologation command exists');
select ok(exists(select 1 from pg_proc where proname='publish_academic_result' and pronamespace='public'::regnamespace),'academic result publication command exists');
select ok(exists(select 1 from pg_proc where proname='correct_published_result' and pronamespace='public'::regnamespace),'published assessment correction command exists');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='schools' and column_name='pedagogical_parallelism'),'pedagogical parallelism is explicit school configuration');
select ok(position('FINAL_EXAM_ONLY_ALLOWED_FOR_9_AND_12' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'final exam restricted to 9th and 12th classes');
select ok(position('PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'final calculation requires configured pedagogical regime');
select ok(position('when pedagogical_parallelism then (2 * nd + ne) / 3' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'parallelism formula is explicit');
select ok(position('else (nd + ne) / 2' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'non-parallelism formula is explicit');
select ok(position('PUBLISHED_RESULT_REQUIRES_CORRECTION' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'published final result cannot be silently overwritten');
select ok(position('RESULT_NOT_CALCULATED' in pg_get_functiondef('public.homologate_academic_result(uuid,text,text)'::regprocedure)) > 0,'homologation requires calculated result');
select ok(position('RESULT_NOT_HOMOLOGATED' in pg_get_functiondef('public.publish_academic_result(uuid,text,text)'::regprocedure)) > 0,'publication requires homologation');
select ok(position('CORRECTION_REASON_REQUIRED' in pg_get_functiondef('public.correct_published_result(uuid,numeric,public.assessment_result_status,text,text,text,text)'::regprocedure)) > 0,'published correction requires a reason');

select * from finish();
rollback;