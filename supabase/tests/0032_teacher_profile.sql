-- SIGE 0047 regression — teacher profile read model
begin;
select plan(2);

select ok(exists(select 1 from pg_class where relname='teacher_profile' and relkind='v'),'teacher profile view exists');
select ok(coalesce((select reloptions @> array['security_invoker=true'] from pg_class where oid='public.teacher_profile'::regclass),false),'teacher profile uses invoker security');

select * from finish();
rollback;
