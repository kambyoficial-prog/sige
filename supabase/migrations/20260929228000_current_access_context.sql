-- SIGE 0042 — authenticated access context
--
-- The application needs one authoritative server-side snapshot of the current
-- account, person, schools, roles and permissions. This is not authorization
-- itself; every command still re-checks permission in PostgreSQL.

create or replace function public.current_access_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $sige$
declare
  actor uuid := (select auth.uid());
  account_id uuid;
  person_id uuid;
  context jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select aa.id, aa.person_id
    into account_id, person_id
  from public.app_accounts aa
  where aa.auth_user_id = actor
    and aa.active
  for share;

  if account_id is null then
    raise exception 'APP_ACCOUNT_NOT_FOUND';
  end if;

  select jsonb_build_object(
    'auth_user_id', actor,
    'app_account_id', account_id,
    'person_id', person_id,
    'person', (
      select jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'email', p.email,
        'phone', p.phone
      )
      from public.people p
      where p.id = person_id
    ),
    'memberships', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'school_id', ar.school_id,
          'school_code', s.code,
          'school_name', s.name,
          'roles', (
            select coalesce(jsonb_agg(
              jsonb_build_object(
                'code', r.code,
                'name', r.name
              )
              order by r.code
            ), '[]'::jsonb)
            from public.account_roles ar2
            join public.roles r on r.id = ar2.role_id
            where ar2.app_account_id = account_id
              and ar2.school_id = ar.school_id
              and ar2.active
              and (ar2.starts_on is null or ar2.starts_on <= current_date)
              and (ar2.ends_on is null or ar2.ends_on >= current_date)
          ),
          'permissions', (
            select coalesce(jsonb_agg(distinct p.code order by p.code), '[]'::jsonb)
            from public.account_roles ar3
            join public.role_permissions rp on rp.role_id = ar3.role_id
            join public.permissions p on p.id = rp.permission_id
            where ar3.app_account_id = account_id
              and ar3.school_id = ar.school_id
              and ar3.active
              and (ar3.starts_on is null or ar3.starts_on <= current_date)
              and (ar3.ends_on is null or ar3.ends_on >= current_date)
          )
        )
        order by s.code
      )
      from (
        select distinct school_id
        from public.account_roles
        where app_account_id = account_id
          and active
          and (starts_on is null or starts_on <= current_date)
          and (ends_on is null or ends_on >= current_date)
      ) ar
      join public.schools s on s.id = ar.school_id
    ), '[]'::jsonb)
  )
  into context;

  return context;
end;
$sige$;

revoke all on function public.current_access_context() from public;
grant execute on function public.current_access_context() to authenticated;
