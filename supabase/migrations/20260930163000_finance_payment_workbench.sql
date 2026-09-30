-- SIGE — Secretariat payment verification workbench
-- Adds school-scoped receipt sequencing and a finance workbench read boundary.

create table if not exists public.school_receipt_sequences (
  school_id uuid primary key references public.schools(id) on delete cascade,
  next_number bigint not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.school_receipt_sequences enable row level security;

drop policy if exists school_receipt_sequences_manage on public.school_receipt_sequences;
create policy school_receipt_sequences_manage on public.school_receipt_sequences
for all to authenticated
using (private.has_permission('finance.manage', school_id))
with check (private.has_permission('finance.manage', school_id));

-- The production function generates REC-YYYY-NNNNNN when the UI requests AUTO.
-- Existing explicit numbers remain accepted for controlled migration/backfill.
