-- SIGE 0023 — academic lifecycle regression
begin;
select plan(8);

select ok(exists(
  select 1 from pg_indexes
  where schemaname='public'
    and indexname='academic_years_one_open_per_school_uidx'
),'only one open academic year is enforced per school');

select ok(position('OPEN_ASSESSMENTS_REMAIN' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close blocks open assessments');
select ok(position('OPEN_ASSESSMENT_PERIODS_REMAIN' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close blocks open assessment periods');
select ok(position('PENDING_ENROLLMENTS_REMAIN' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close blocks pending enrollments');
select ok(position('update public.student_enrollments' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close completes active enrollments');
select ok(position('update public.class_placements' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close ends class placements');
select ok(position('update public.schedule_entries' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close ends schedule entries');
select ok(position('update public.class_groups' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close closes class groups');

select * from finish();
rollback;