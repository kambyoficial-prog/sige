-- Student authentication: school number + password, without requiring a student email.
insert into public.roles (code,name,description) values ('STUDENT','Aluno','Acesso individual do aluno ao portal SIGE.') on conflict (code) do update set name=excluded.name, description=excluded.description;

create or replace function private.student_login_identity(p_school_number text)
returns table(auth_user_id uuid, login_email text)
language sql stable security definer set search_path to ''
as $$
  select aa.auth_user_id, au.email
  from public.students s
  join public.app_accounts aa on aa.person_id = s.person_id and aa.active
  join auth.users au on au.id = aa.auth_user_id
  join public.account_roles ar on ar.app_account_id = aa.id and ar.active
  join public.roles r on r.id = ar.role_id and r.code = 'STUDENT'
  where s.school_number = upper(trim(p_school_number)) and s.status = 'ACTIVE'
  limit 1;
$$;
revoke all on function private.student_login_identity(text) from public;
grant execute on function private.student_login_identity(text) to service_role;
