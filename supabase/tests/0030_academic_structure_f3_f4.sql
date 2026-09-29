-- SIGE 0044 regression — academic structure operational boundary
begin;
select plan(8);

select ok(exists(select 1 from pg_class where relname='course_offering_directory' and relkind='v'),'course offering directory exists');
select ok((select reloptions @> array['security_invoker=true'] from pg_class where oid='public.course_offering_directory'::regclass),'course offering directory uses invoker security');
select ok(exists(select 1 from pg_proc where proname='assign_class_group_director' and pronamespace='public'::regnamespace),'class director command exists');
select ok(position('DIRECTOR_MUST_TEACH_CLASS' in pg_get_functiondef('public.assign_class_group_director(uuid,uuid,date,date,text,text,text)'::regprocedure)) > 0,'director assignment requires teacher assignment');
select ok(exists(select 1 from pg_policy where polname='class_group_leadership_read' and polrelid='public.class_group_leadership'::regclass),'class leadership has school-scoped read policy');
select ok(exists(select 1 from pg_class where relname='class_group_directory' and relkind='v'),'class directory exists');
select ok(exists(select 1 from pg_proc where proname='generate_class_offerings' and pronamespace='public'::regnamespace),'offering generation command exists');
select ok(exists(select 1 from pg_proc where proname='assign_teacher_to_offering' and pronamespace='public'::regnamespace),'teacher assignment command exists');

select * from finish();
rollback;
