-- SIGE 0043 — authorization respects school lifecycle
--
-- A disabled school must not remain an operational authorization scope.

create or replace function private.has_permission(
  p_permission_code text,
  p_school_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $sige$
  select exists (
    select 1
    from public.schools s
    join public.account_roles ar
      on ar.school_id = s.id
     and ar.active
     and (ar.starts_on is null or ar.starts_on <= current_date)
     and (ar.ends_on is null or ar.ends_on >= current_date)
    join public.app_accounts aa
      on aa.id = ar.app_account_id
     and aa.auth_user_id = (select auth.uid())
     and aa.active
    join public.role_permissions rp on rp.role_id = ar.role_id
    join public.permissions p on p.id = rp.permission_id
    where s.id = p_school_id
      and s.active
      and p.code = p_permission_code
  );
$sige$;

revoke all on function private.has_permission(text, uuid) from public;
