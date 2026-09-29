-- SIGE 0043 regression
begin;
select plan(3);

select ok(position('s.active' in pg_get_functiondef('private.has_permission(text,uuid)'::regprocedure)) > 0,'permission checks school active state');
select ok(position('aa.auth_user_id = (select auth.uid())' in pg_get_functiondef('private.has_permission(text,uuid)'::regprocedure)) > 0,'permission remains bound to authenticated account');
select ok(position('set search_path = ''''' in pg_get_functiondef('private.has_permission(text,uuid)'::regprocedure)) > 0,'permission function pins search_path');

select * from finish();
rollback;