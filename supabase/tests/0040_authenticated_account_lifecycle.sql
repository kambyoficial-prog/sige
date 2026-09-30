-- 0040 — authenticated account lifecycle / admin-boundary invariants
begin;

do $$
declare
  account_policy_count integer;
begin
  select count(*) into account_policy_count
  from pg_policies
  where schemaname='public'
    and tablename='app_accounts'
    and policyname='app_accounts_self_read'
    and cmd='SELECT'
    and 'authenticated'=any(roles);

  if account_policy_count <> 1 then
    raise exception 'app_accounts self-read policy missing';
  end if;

  if has_function_privilege('anon','public.complete_first_access_account()','execute') then
    raise exception 'anonymous first-access mutation must not be executable';
  end if;

  if not has_function_privilege('authenticated','public.complete_first_access_account()','execute') then
    raise exception 'authenticated first-access mutation must be executable';
  end if;

  if has_function_privilege('public','public.complete_first_access_account()','execute') then
    raise exception 'PUBLIC first-access mutation must not be executable';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='complete_first_access_account'
      and (
        not p.prosecdef
        or p.proconfig is null
        or not exists (select 1 from unnest(p.proconfig) c where c='search_path=""')
      )
  ) then
    raise exception 'first-access RPC security invariant failed';
  end if;

  if not has_function_privilege('anon','public.resolve_student_login_email(text)','execute') then
    raise exception 'anonymous student login resolver must be executable';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='resolve_student_login_email'
      and (
        not p.prosecdef
        or p.proconfig is null
        or not exists (select 1 from unnest(p.proconfig) c where c='search_path=""')
      )
  ) then
    raise exception 'student login resolver security invariant failed';
  end if;
end $$;

rollback;
