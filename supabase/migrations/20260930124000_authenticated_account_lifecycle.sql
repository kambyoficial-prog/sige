-- SIGE: remove unnecessary service-role dependency from authenticated account lifecycle.
-- Authenticated users may read only their own app account state.
drop policy if exists app_accounts_self_read on public.app_accounts;
create policy app_accounts_self_read
on public.app_accounts
for select
to authenticated
using ((select auth.uid()) = auth_user_id);

-- Narrow authenticated transition for first access. No direct UPDATE grant is exposed.
create or replace function public.complete_first_access_account()
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
begin
  if (select auth.uid()) is null then
    return false;
  end if;

  update public.app_accounts
  set first_access_required = false,
      activated_at = now()
  where auth_user_id = (select auth.uid())
    and active = true
    and first_access_required = true;

  return found;
end;
$$;

revoke all on function public.complete_first_access_account() from public;
grant execute on function public.complete_first_access_account() to authenticated;
