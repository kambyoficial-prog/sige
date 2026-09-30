-- SIGE — student access provisioning
-- Student login uses the school number as the public identifier while
-- Supabase Auth keeps a non-contact internal email identity.

insert into public.permissions (code, name, description)
values (
  'student.access.manage',
  'Gerir acesso de alunos',
  'Provisionar, activar e gerir o acesso autenticável dos alunos.'
)
on conflict (code) do update
set name = excluded.name,
    description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'student.access.manage'
where r.code in ('DIRECTION', 'SECRETARIAT')
on conflict do nothing;

-- The database intentionally stores no student password or Auth secret.
-- The server-side provisioning action creates the Auth identity and the
-- app_accounts/account_roles relationship as one compensating workflow.
