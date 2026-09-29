-- SIGE 0042/0043/0045 regression — people, admission and enrollment read boundary
begin;
select plan(9);

select ok(exists(select 1 from pg_proc where proname='register_student' and pronamespace='public'::regnamespace),'student registration command exists');
select ok(exists(select 1 from pg_proc where proname='create_guardian' and pronamespace='public'::regnamespace),'guardian command exists');
select ok(position('set search_path = ' in pg_get_functiondef('public.register_student(uuid,text,text,text,text,text,date,text,text,text,text,date,text,text)'::regprocedure)) > 0,'student registration pins search_path');
select ok(position('set search_path = ' in pg_get_functiondef('public.create_guardian(uuid,uuid,text,text,text,text,text,text,text,date,text,boolean,boolean,text,text)'::regprocedure)) > 0,'guardian command pins search_path');

select ok(exists(select 1 from pg_policy where polname='people_read' and polrelid='public.people'::regclass),'people read policy is explicit');
select ok(position('true' in pg_get_expr((select polqual from pg_policy where polname='people_read' and polrelid='public.people'::regclass), 'public.people'::regclass)) = 0,'people are not globally readable');

select ok(coalesce((select reloptions @> array['security_invoker=true'] from pg_class where oid='public.student_directory'::regclass),false),'student directory uses invoker security');
select ok(coalesce((select reloptions @> array['security_invoker=true'] from pg_class where oid='public.student_profile'::regclass),false),'student profile uses invoker security');
select ok(exists(select 1 from pg_policy where polname='student_identifiers_read' and polrelid='public.student_identifiers'::regclass),'student identifiers have an explicit read boundary');

select * from finish();
rollback;
