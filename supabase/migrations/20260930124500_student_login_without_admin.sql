-- Resolve the synthetic Auth identity used by student accounts without exposing Auth Admin APIs.
create or replace function public.resolve_student_login_email(p_school_number text)
returns text
language sql
stable
security definer
set search_path to ''
as $$
  select 'student.' || s.id::text || '@auth.sige.local'
  from public.students s
  join public.app_accounts aa
    on aa.person_id = s.person_id
   and aa.active
  join public.account_roles ar
    on ar.app_account_id = aa.id
   and ar.active
  join public.roles r
    on r.id = ar.role_id
   and r.code = 'STUDENT'
  where s.school_number = upper(trim(p_school_number))
    and s.status = 'ACTIVE'
  limit 1;
$$;

revoke all on function public.resolve_student_login_email(text) from public;
grant execute on function public.resolve_student_login_email(text) to anon, authenticated;
