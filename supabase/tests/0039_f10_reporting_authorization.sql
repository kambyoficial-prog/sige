-- 0039 — F10 reporting authorization invariants
begin;
do $$
declare
  report_views text[] := array[
    'report_student_demographics','report_enrollment_status','report_enrollment_grade',
    'report_class_capacity','report_finance_summary','report_academic_outcomes',
    'report_enrollment_exits','report_class_transfers'
  ];
  exposed_views text[];
  insecure_functions text[];
begin
  if not exists (
    select 1 from public.permissions where code='reports.read'
  ) then
    raise exception 'reports.read permission missing';
  end if;

  if exists (
    select 1
    from public.roles r
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions p on p.id=rp.permission_id
    where r.code='SECRETARIAT' and p.code='reports.read'
  ) then
    raise exception 'SECRETARIAT must not have reports.read';
  end if;

  if not exists (
    select 1
    from public.roles r
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions p on p.id=rp.permission_id
    where r.code='DIRECTION' and p.code='reports.read'
  ) then
    raise exception 'DIRECTION must have reports.read';
  end if;

  if not exists (
    select 1
    from public.roles r
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions p on p.id=rp.permission_id
    where r.code='PEDAGOGICAL_DIRECTION' and p.code='reports.read'
  ) then
    raise exception 'PEDAGOGICAL_DIRECTION must have reports.read';
  end if;

  select array_agg(v order by v) into exposed_views
  from unnest(report_views) v
  where has_table_privilege('authenticated','public.'||v,'SELECT');
  if exposed_views is not null then
    raise exception 'report views remain directly exposed to authenticated: %',exposed_views;
  end if;

  select array_agg(p.proname order by p.proname) into insecure_functions
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='get_report_rows'
    and p.prosecdef
    and (
      pg_get_functiondef(p.oid) !~* 'auth[.]uid[[:space:]]*[(][[:space:]]*[)]'
      or pg_get_functiondef(p.oid) !~* 'search_path'
    );
  if insecure_functions is not null then
    raise exception 'get_report_rows security invariant failed: %',insecure_functions;
  end if;

  if has_function_privilege('anon','public.get_report_rows(text,uuid)','execute') then
    raise exception 'anonymous execution exposed for get_report_rows';
  end if;
end $$;
rollback;
