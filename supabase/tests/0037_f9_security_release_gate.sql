begin;
do $$
declare n integer;
begin
select count(*) into n from information_schema.role_routine_grants
where grantee='anon' and routine_schema='public' and privilege_type='EXECUTE'
and routine_name in ('create_charge','record_payment','confirm_payment','allocate_payment','reverse_payment','enroll_student','register_student','place_student_in_class');
if n<>0 then raise exception 'anonymous command execution exposed: %',n; end if;
if not exists(select 1 from pg_views where schemaname='public' and viewname='finance_balance_directory') then raise exception 'financial balance read model missing'; end if;
end $$;
rollback;