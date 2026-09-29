-- SIGE 0015 — Command idempotency infrastructure
--
create schema if not exists private;

-- This table is deliberately private. It is not a Data API surface.
-- Critical public commands will use it inside their own transaction.

create table if not exists private.command_idempotency (
  id bigint generated always as identity primary key,
  actor_auth_user_id uuid not null references auth.users(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  command_name text not null,
  idempotency_key text not null,
  request_hash text,
  status text not null check (status in ('STARTED','COMPLETED','FAILED')),
  result_payload jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz,
  unique (actor_auth_user_id, school_id, command_name, idempotency_key)
);

create index if not exists command_idempotency_expiry_idx
  on private.command_idempotency (expires_at)
  where expires_at is not null;

revoke all on private.command_idempotency from public, anon, authenticated;

comment on table private.command_idempotency is
  'Private transaction-local idempotency registry for critical SIGE commands.';

comment on column private.command_idempotency.request_hash is
  'Canonical hash of the command payload. A reused key with a different hash must be rejected.';

comment on column private.command_idempotency.result_payload is
  'Small deterministic command result; large domain documents belong in their own tables.';
