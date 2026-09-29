-- SIGE 0045 regression
begin;
select plan(4);

select ok(exists(select 1 from pg_proc where proname='current_access_context' and pronamespace='public'::regnamespace),'current access context command exists');
select ok(position('auth.uid()' in pg_get_functiondef('public.current_access_context()'::regprocedure)) > 0,'access context is bound to auth identity');
select ok(position('APP_ACCOUNT_NOT_FOUND' in pg_get_functiondef('public.current_access_context()'::regprocedure)) > 0,'unprovisioned auth users are rejected');
select ok(coalesce((select has_function_privilege('anon','public.current_access_context()','EXECUTE')),false) = false,'anonymous callers cannot execute access context');

select * from finish();
rollback;