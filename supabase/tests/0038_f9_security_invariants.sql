-- 0038 — F9 live security invariants
begin;
do $$
declare missing_rls text[]; exposed_commands text[]; insecure_definers text[]; missing_invoker_views text[];
begin
  select array_agg(t order by t) into missing_rls
  from unnest(array['students','student_enrollments','student_registrations','class_groups','course_offerings','teacher_assignments','student_course_participations','assessments','assessment_results','academic_results','class_sessions','charges','payments','payment_allocations','receipts']) t
  where not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=t and c.relkind='r' and c.relrowsecurity);
  if missing_rls is not null then raise exception 'critical tables without RLS: %',missing_rls; end if;

  select array_agg(p.proname order by p.proname) into insecure_definers
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
    and (pg_get_functiondef(p.oid) !~* 'auth[.]uid[[:space:]]*[(][[:space:]]*[)]' or pg_get_functiondef(p.oid) !~* 'search_path');
  if insecure_definers is not null then raise exception 'SECURITY DEFINER functions missing auth/search_path invariant: %',insecure_definers; end if;

  select array_agg(r.routine_name order by r.routine_name) into exposed_commands
  from information_schema.role_routine_grants r
  where r.grantee='anon' and r.routine_schema='public' and r.privilege_type='EXECUTE';
  if exposed_commands is not null then raise exception 'anonymous execution exposed for public routines: %',exposed_commands; end if;

  select array_agg(v.viewname order by v.viewname) into missing_invoker_views
  from pg_views v
  where v.schemaname='public'
    and v.viewname in ('student_directory','enrollment_directory','teacher_directory','class_group_directory','assessment_gradebook','academic_result_pauta','finance_charge_directory','finance_payment_directory','finance_balance_directory')
    and not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=v.viewname and 'security_invoker=true'=any(coalesce(c.reloptions,array[]::text[])));
  if missing_invoker_views is not null then raise exception 'read models without security_invoker=true: %',missing_invoker_views; end if;
end $$;
rollback;