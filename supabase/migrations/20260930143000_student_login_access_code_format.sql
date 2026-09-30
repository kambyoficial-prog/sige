create or replace function public.resolve_student_login_email(p_school_number text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select 'student.' || s.id::text || '@auth.sige.local'
  from public.students s
  join public.app_accounts a on a.person_id = s.person_id and a.active
  join public.account_roles ar on ar.app_account_id = a.id and ar.active
  join public.roles r on r.id = ar.role_id and r.code = 'STUDENT'
  where s.status = 'ACTIVE'
    and (
      s.school_number = trim(p_school_number)
      or s.school_number = split_part(trim(p_school_number), '.', 1)
    )
  order by case when s.school_number = trim(p_school_number) then 0 else 1 end
  limit 1
$$;
