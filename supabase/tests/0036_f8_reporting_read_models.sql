begin;
do $$
declare n integer;
begin
select count(*) into n from pg_views where schemaname='public' and viewname in ('report_student_demographics','report_enrollment_status','report_enrollment_grade','report_class_capacity','report_finance_summary','report_academic_outcomes');
if n<>6 then raise exception 'F8 report views missing: %',n; end if;
if (select count(*) from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name like 'report_%' and privilege_type='SELECT')<6 then raise exception 'F8 report read grants incomplete'; end if;
if not exists(select 1 from pg_views where schemaname='public' and viewname='report_finance_summary') then raise exception 'F8 finance report missing'; end if;
end $$;
rollback;