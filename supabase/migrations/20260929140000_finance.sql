-- SIGE 0005 — Finance domain
-- Accounts receivable only. This is not a general ledger.

create type public.fee_frequency as enum ('ONCE','MONTHLY','QUARTERLY','ANNUAL','CUSTOM');
create type public.student_service_status as enum ('ACTIVE','ENDED','CANCELLED');
create type public.charge_status as enum ('OPEN','PARTIALLY_PAID','PAID','OVERDUE','CANCELLED','WAIVED');
create type public.payment_status as enum ('PENDING','CONFIRMED','REVERSED','CANCELLED');
create type public.payment_method as enum ('CASH','BANK_TRANSFER','CARD','MOBILE_MONEY','OTHER');
create type public.adjustment_type as enum ('DISCOUNT','WAIVER','SURCHARGE','CORRECTION','REVERSAL');

create table public.fee_types (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table public.fee_plans (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  name text not null,
  version integer not null default 1,
  effective_from date not null,
  effective_until date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, academic_year_id, name, version),
  constraint fee_plans_version_ck check (version > 0),
  constraint fee_plans_dates_ck check (
    effective_until is null or effective_until >= effective_from
  )
);

create table public.fee_plan_items (
  id uuid primary key default gen_random_uuid(),
  fee_plan_id uuid not null references public.fee_plans(id) on delete cascade,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  label text not null,
  amount numeric(12,2) not null,
  currency char(3) not null default 'MZN',
  frequency public.fee_frequency not null default 'ONCE',
  due_day smallint,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (fee_plan_id, fee_type_id, label),
  constraint fee_plan_items_amount_ck check (amount >= 0),
  constraint fee_plan_items_due_day_ck check (due_day is null or due_day between 1 and 31)
);

create table public.student_services (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  service_type text not null,
  status public.student_service_status not null default 'ACTIVE',
  starts_on date not null,
  ends_on date,
  reference_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_services_dates_ck check (
    ends_on is null or ends_on >= starts_on
  )
);

create table public.transport_services (
  id uuid primary key default gen_random_uuid(),
  student_service_id uuid not null unique references public.student_services(id) on delete cascade,
  route_name text,
  pickup_stop text,
  dropoff_stop text,
  monthly_amount numeric(12,2),
  currency char(3) not null default 'MZN',
  created_at timestamptz not null default now(),
  constraint transport_services_amount_ck check (
    monthly_amount is null or monthly_amount >= 0
  )
);

create table public.charges (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  enrollment_id uuid references public.student_enrollments(id) on delete restrict,
  fee_plan_item_id uuid references public.fee_plan_items(id) on delete restrict,
  student_service_id uuid references public.student_services(id) on delete restrict,
  reference_code text,
  description text not null,
  amount numeric(12,2) not null,
  currency char(3) not null default 'MZN',
  due_on date not null,
  status public.charge_status not null default 'OPEN',
  source_rule text,
  issued_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id) on delete set null,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint charges_amount_ck check (amount >= 0),
  constraint charges_cancel_ck check (
    (status = 'CANCELLED' and cancelled_at is not null)
    or
    (status <> 'CANCELLED' and cancelled_at is null)
  )
);

create index charges_student_status_idx on public.charges (student_id, status, due_on);
create index charges_school_due_idx on public.charges (school_id, due_on, status);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  amount numeric(12,2) not null,
  currency char(3) not null default 'MZN',
  method public.payment_method not null,
  status public.payment_status not null default 'PENDING',
  paid_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  external_reference text,
  notes text,
  created_at timestamptz not null default now(),
  constraint payments_amount_ck check (amount > 0),
  constraint payments_confirmation_ck check (
    (status = 'CONFIRMED' and confirmed_at is not null and confirmed_by is not null)
    or
    (status <> 'CONFIRMED')
  )
);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  charge_id uuid not null references public.charges(id) on delete restrict,
  amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  unique (payment_id, charge_id),
  constraint payment_allocations_amount_ck check (amount > 0)
);

create index payment_allocations_charge_idx
  on public.payment_allocations (charge_id);

create table public.charge_adjustments (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.charges(id) on delete restrict,
  type public.adjustment_type not null,
  amount numeric(12,2) not null,
  reason text not null,
  approved_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint charge_adjustments_amount_ck check (amount > 0)
);

create table public.payment_reversals (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references public.payments(id) on delete restrict,
  amount numeric(12,2) not null,
  reason text not null,
  reversed_by uuid references auth.users(id) on delete set null,
  reversed_at timestamptz not null default now(),
  constraint payment_reversals_amount_ck check (amount > 0)
);

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references public.payments(id) on delete restrict,
  receipt_number text not null,
  issued_at timestamptz not null default now(),
  issued_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  cancellation_reason text,
  unique (receipt_number)
);

-- Derived balance projection. It is intentionally not stored on students.
create or replace view public.student_financial_balances
with (security_invoker = true)
as
select
  c.school_id,
  c.student_id,
  sum(
    case
      when c.status in ('CANCELLED','WAIVED') then 0
      else c.amount
    end
  ) as charged_amount,
  coalesce(sum(
    case
      when p.status = 'CONFIRMED' then pa.amount
      else 0
    end
  ), 0) as paid_amount,
  sum(
    case
      when c.status in ('CANCELLED','WAIVED') then 0
      else c.amount
    end
  ) - coalesce(sum(
    case
      when p.status = 'CONFIRMED' then pa.amount
      else 0
    end
  ), 0) as balance_amount
from public.charges c
left join public.payment_allocations pa on pa.charge_id = c.id
left join public.payments p on p.id = pa.payment_id
group by c.school_id, c.student_id;

alter table public.fee_types enable row level security;
alter table public.fee_plans enable row level security;
alter table public.fee_plan_items enable row level security;
alter table public.student_services enable row level security;
alter table public.transport_services enable row level security;
alter table public.charges enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.charge_adjustments enable row level security;
alter table public.payment_reversals enable row level security;
alter table public.receipts enable row level security;

create policy fee_types_read on public.fee_types
  for select to authenticated
  using ((select private.has_permission('finance.read', school_id)));

create policy fee_types_manage on public.fee_types
  for all to authenticated
  using ((select private.has_permission('finance.manage', school_id)))
  with check ((select private.has_permission('finance.manage', school_id)));

create policy fee_plans_read on public.fee_plans
  for select to authenticated
  using ((select private.has_permission('finance.read', school_id)));

create policy fee_plans_manage on public.fee_plans
  for all to authenticated
  using ((select private.has_permission('finance.manage', school_id)))
  with check ((select private.has_permission('finance.manage', school_id)));

create policy fee_plan_items_read on public.fee_plan_items
  for select to authenticated
  using (
    exists (
      select 1 from public.fee_plans fp
      where fp.id = fee_plan_items.fee_plan_id
        and (select private.has_permission('finance.read', fp.school_id))
    )
  );

create policy fee_plan_items_manage on public.fee_plan_items
  for all to authenticated
  using (
    exists (
      select 1 from public.fee_plans fp
      where fp.id = fee_plan_items.fee_plan_id
        and (select private.has_permission('finance.manage', fp.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.fee_plans fp
      where fp.id = fee_plan_items.fee_plan_id
        and (select private.has_permission('finance.manage', fp.school_id))
    )
  );

create policy student_services_read on public.student_services
  for select to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_services.student_id
        and (select private.has_permission('finance.read', s.school_id))
    )
  );

create policy student_services_manage on public.student_services
  for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_services.student_id
        and (select private.has_permission('finance.manage', s.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_services.student_id
        and (select private.has_permission('finance.manage', s.school_id))
    )
  );

create policy transport_services_read on public.transport_services
  for select to authenticated
  using (
    exists (
      select 1
      from public.student_services ss
      join public.students s on s.id = ss.student_id
      where ss.id = transport_services.student_service_id
        and (select private.has_permission('finance.read', s.school_id))
    )
  );

create policy transport_services_manage on public.transport_services
  for all to authenticated
  using (
    exists (
      select 1
      from public.student_services ss
      join public.students s on s.id = ss.student_id
      where ss.id = transport_services.student_service_id
        and (select private.has_permission('finance.manage', s.school_id))
    )
  )
  with check (
    exists (
      select 1
      from public.student_services ss
      join public.students s on s.id = ss.student_id
      where ss.id = transport_services.student_service_id
        and (select private.has_permission('finance.manage', s.school_id))
    )
  );

create policy charges_read on public.charges
  for select to authenticated
  using ((select private.has_permission('finance.read', school_id)));

create policy charges_manage on public.charges
  for all to authenticated
  using ((select private.has_permission('finance.manage', school_id)))
  with check ((select private.has_permission('finance.manage', school_id)));

create policy payments_read on public.payments
  for select to authenticated
  using ((select private.has_permission('finance.read', school_id)));

create policy payments_manage on public.payments
  for all to authenticated
  using ((select private.has_permission('finance.manage', school_id)))
  with check ((select private.has_permission('finance.manage', school_id)));

create policy allocations_read on public.payment_allocations
  for select to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = payment_allocations.payment_id
        and (select private.has_permission('finance.read', p.school_id))
    )
  );

create policy allocations_manage on public.payment_allocations
  for all to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = payment_allocations.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.payments p
      where p.id = payment_allocations.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  );

create policy adjustments_read on public.charge_adjustments
  for select to authenticated
  using (
    exists (
      select 1 from public.charges c
      where c.id = charge_adjustments.charge_id
        and (select private.has_permission('finance.read', c.school_id))
    )
  );

create policy adjustments_manage on public.charge_adjustments
  for all to authenticated
  using (
    exists (
      select 1 from public.charges c
      where c.id = charge_adjustments.charge_id
        and (select private.has_permission('finance.manage', c.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.charges c
      where c.id = charge_adjustments.charge_id
        and (select private.has_permission('finance.manage', c.school_id))
    )
  );

create policy reversals_read on public.payment_reversals
  for select to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = payment_reversals.payment_id
        and (select private.has_permission('finance.read', p.school_id))
    )
  );

create policy reversals_manage on public.payment_reversals
  for all to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = payment_reversals.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.payments p
      where p.id = payment_reversals.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  );

create policy receipts_read on public.receipts
  for select to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = receipts.payment_id
        and (select private.has_permission('finance.read', p.school_id))
    )
  );

create policy receipts_manage on public.receipts
  for all to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = receipts.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.payments p
      where p.id = receipts.payment_id
        and (select private.has_permission('finance.manage', p.school_id))
    )
  );
