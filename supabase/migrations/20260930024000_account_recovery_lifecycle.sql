-- SIGE — account recovery lifecycle
create table if not exists public.account_recovery_cases (
  id uuid primary key default gen_random_uuid(),
  app_account_id uuid not null references public.app_accounts(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  requested_at timestamptz not null default now(),
  requested_by_auth_user_id uuid references auth.users(id) on delete set null,
  verification_method text not null,
  verification_notes text,
  status text not null default 'REQUESTED',
  approved_by_auth_user_id uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz,
  invalidated_sessions boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  constraint account_recovery_status_ck check (status in ('REQUESTED','VERIFIED','APPROVED','COMPLETED','REJECTED','EXPIRED','CANCELLED')),
  constraint account_recovery_verification_method_ck check (verification_method in ('SELF_SERVICE_EMAIL','IN_PERSON_SECRETARIAT','ADMIN_ASSISTED','DUAL_CONTROL'))
);

create index if not exists account_recovery_cases_account_idx on public.account_recovery_cases(app_account_id, requested_at desc);
create index if not exists account_recovery_cases_school_idx on public.account_recovery_cases(school_id, requested_at desc);

alter table public.account_recovery_cases enable row level security;
drop policy if exists account_recovery_cases_read on public.account_recovery_cases;
create policy account_recovery_cases_read on public.account_recovery_cases
for select to authenticated using (private.has_permission('user.read', school_id));

insert into public.permissions (code,name,description) values
 ('user.recover','Recuperar acesso','Iniciar e concluir recuperação assistida de contas institucionais.')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='user.recover'
where r.code in ('DIRECTION','SECRETARIAT') on conflict do nothing;
