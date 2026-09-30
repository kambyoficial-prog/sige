-- F10 — reporting authorization boundary
-- Reports are read models, but they are not an authorization boundary by themselves.
-- The Data API must not expose aggregate report views to roles that may read the
-- underlying operational records but are not allowed to consume school reports.

begin;

insert into public.permissions (code,name,description)
values (
  'reports.read',
  'Consultar relatórios',
  'Consultar relatórios institucionais e indicadores consolidados.'
)
on conflict (code) do update
set name=excluded.name, description=excluded.description;

insert into public.role_permissions (role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code='reports.read'
where r.code in ('DIRECTION','PEDAGOGICAL_DIRECTION')
on conflict do nothing;

create or replace function public.get_report_rows(
  p_report text,
  p_academic_year_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  result jsonb;
  actor uuid := (select auth.uid());
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_report is null or p_report not in (
    'report_student_demographics',
    'report_enrollment_status',
    'report_enrollment_grade',
    'report_class_capacity',
    'report_finance_summary',
    'report_academic_outcomes',
    'report_enrollment_exits',
    'report_class_transfers'
  ) then
    raise exception 'REPORT_NOT_FOUND';
  end if;

  if p_report='report_finance_summary' then
    if not (
      (select private.has_permission('finance.read',s.school_id))
      or (select private.has_permission('finance.manage',s.school_id))
    ) then
      raise exception 'FORBIDDEN';
    end if;
  elsif not exists (
    select 1
    from public.app_accounts aa
    join public.memberships m on m.person_id=aa.person_id
    where aa.auth_user_id=actor
      and aa.active
      and (select private.has_permission('reports.read',m.school_id))
  ) then
    raise exception 'FORBIDDEN';
  end if;

  case p_report
    when 'report_student_demographics' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_student_demographics x;

    when 'report_enrollment_status' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_enrollment_status x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_enrollment_grade' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_enrollment_grade x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_class_capacity' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_class_capacity x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_finance_summary' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_finance_summary x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_academic_outcomes' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_academic_outcomes x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_enrollment_exits' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_enrollment_exits x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;

    when 'report_class_transfers' then
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result
      from public.report_class_transfers x
      where p_academic_year_id is null or x.academic_year_id=p_academic_year_id;
  end case;

  return coalesce(result,'[]'::jsonb);
end;
$$;

revoke all on function public.get_report_rows(text,uuid) from public;
grant execute on function public.get_report_rows(text,uuid) to authenticated;

revoke all on public.report_student_demographics from anon,authenticated;
revoke all on public.report_enrollment_status from anon,authenticated;
revoke all on public.report_enrollment_grade from anon,authenticated;
revoke all on public.report_class_capacity from anon,authenticated;
revoke all on public.report_finance_summary from anon,authenticated;
revoke all on public.report_academic_outcomes from anon,authenticated;
revoke all on public.report_enrollment_exits from anon,authenticated;
revoke all on public.report_class_transfers from anon,authenticated;

commit;
