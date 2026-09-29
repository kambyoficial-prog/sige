-- SIGE 0003 — Bind application accounts to domain identity
-- A technical auth identity is not enough for school authorization.
-- Each application account is explicitly attached to a Person.

alter table public.app_accounts
  add column person_id uuid references public.people(id) on delete restrict;

create unique index app_accounts_person_uq
  on public.app_accounts (person_id)
  where person_id is not null;

comment on column public.app_accounts.auth_user_id is
  'Supabase Auth technical identity. Never use as the school person record.';

comment on column public.app_accounts.person_id is
  'Domain identity represented by this application account.';
