-- SIGE 0006 — Cross-row integrity, timestamps and audit foundation

create table public.audit_events (
  id bigint generated always as identity primary key,
  school_id uuid references public.schools(id) on delete restrict,
  actor_auth_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  occurred_at timestamptz not null default now(),
  reason text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  request_id uuid,
  constraint audit_events_action_ck check (length(trim(action)) >= 2),
  constraint audit_events_entity_ck check (length(trim(entity_type)) >= 2)
);

create index audit_events_school_time_idx
  on public.audit_events (school_id, occurred_at desc);

create index audit_events_entity_idx
  on public.audit_events (entity_type, entity_id, occurred_at desc);

alter table public.audit_events enable row level security;

create policy audit_read on public.audit_events
  for select to authenticated
  using (
    school_id is null
    or (select private.has_permission('administration.manage', school_id))
  );

-- Audit is append-only from application code. Authenticated clients do not
-- receive direct INSERT/UPDATE/DELETE privileges; server-side commands will
-- write events through a controlled path.
revoke insert, update, delete on public.audit_events from authenticated;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'schools','academic_years','people','students','guardians','teachers',
    'staff_members','class_groups','student_enrollments','course_offerings',
    'assessments','assessment_results','student_services','charges','payments'
  ]
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'trg_' || table_name || '_updated_at',
      table_name
    );
    execute format(
      'create trigger %I before update on public.%I
       for each row execute function private.touch_updated_at()',
      'trg_' || table_name || '_updated_at',
      table_name
    );
  end loop;
end $$;

create or replace function private.validate_payment_allocation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  payment_total numeric(12,2);
  allocated_total numeric(12,2);
  payment_state public.payment_status;
  payment_student uuid;
  charge_total numeric(12,2);
  charge_allocated numeric(12,2);
  charge_student uuid;
begin
  select p.amount, p.status, p.student_id
    into payment_total, payment_state, payment_student
  from public.payments p
  where p.id = new.payment_id
  for update;

  if payment_total is null then
    raise exception 'Payment % does not exist', new.payment_id;
  end if;

  if payment_state <> 'CONFIRMED' then
    raise exception 'Only confirmed payments can be allocated';
  end if;

  select c.amount, c.student_id
    into charge_total, charge_student
  from public.charges c
  where c.id = new.charge_id
  for update;

  if charge_total is null then
    raise exception 'Charge % does not exist', new.charge_id;
  end if;

  if charge_student <> payment_student then
    raise exception 'Payment and charge belong to different students';
  end if;

  select coalesce(sum(pa.amount), 0)
    into allocated_total
  from public.payment_allocations pa
  where pa.payment_id = new.payment_id
    and pa.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

  if allocated_total + new.amount > payment_total then
    raise exception 'Payment allocation exceeds payment amount';
  end if;

  select coalesce(sum(pa.amount), 0)
    into charge_allocated
  from public.payment_allocations pa
  join public.payments p on p.id = pa.payment_id
  where pa.charge_id = new.charge_id
    and pa.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    and p.status = 'CONFIRMED';

  if charge_allocated + new.amount > charge_total then
    raise exception 'Payment allocation exceeds charge amount';
  end if;

  return new;
end;
$$;

create constraint trigger trg_validate_payment_allocation
after insert or update on public.payment_allocations
deferrable initially deferred
for each row execute function private.validate_payment_allocation();

create or replace function private.refresh_charge_status(target_charge uuid)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  base_amount numeric(12,2);
  adjustments numeric(12,2);
  paid_amount numeric(12,2);
  net_amount numeric(12,2);
  due_date date;
  current_status public.charge_status;
begin
  select amount, due_on, status
    into base_amount, due_date, current_status
  from public.charges
  where id = target_charge
  for update;

  if not found or current_status in ('CANCELLED','WAIVED') then
    return;
  end if;

  select coalesce(sum(
    case
      when type in ('DISCOUNT','WAIVER','REVERSAL') then -amount
      when type in ('SURCHARGE','CORRECTION') then amount
      else 0
    end
  ), 0)
  into adjustments
  from public.charge_adjustments
  where charge_id = target_charge;

  select coalesce(sum(pa.amount), 0)
  into paid_amount
  from public.payment_allocations pa
  join public.payments p on p.id = pa.payment_id
  where pa.charge_id = target_charge
    and p.status = 'CONFIRMED';

  net_amount := greatest(0, base_amount + adjustments);

  update public.charges
  set status =
    case
      when paid_amount >= net_amount then 'PAID'::public.charge_status
      when paid_amount > 0 then 'PARTIALLY_PAID'::public.charge_status
      when due_date < current_date then 'OVERDUE'::public.charge_status
      else 'OPEN'::public.charge_status
    end
  where id = target_charge;
end;
$$;

create or replace function private.refresh_charge_status_trigger()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform private.refresh_charge_status(coalesce(new.charge_id, old.charge_id));
  return coalesce(new, old);
end;
$$;

create trigger trg_charge_adjustment_refresh
after insert or update or delete on public.charge_adjustments
for each row execute function private.refresh_charge_status_trigger();

create trigger trg_payment_allocation_refresh
after insert or update or delete on public.payment_allocations
for each row execute function private.refresh_charge_status_trigger();

create or replace view public.student_financial_balances
with (security_invoker = true)
as
select
  c.school_id,
  c.student_id,
  sum(
    case
      when c.status in ('CANCELLED','WAIVED') then 0
      else greatest(
        0,
        c.amount + coalesce((
          select sum(
            case
              when ca.type in ('DISCOUNT','WAIVER','REVERSAL') then -ca.amount
              when ca.type in ('SURCHARGE','CORRECTION') then ca.amount
              else 0
            end
          )
          from public.charge_adjustments ca
          where ca.charge_id = c.id
        ), 0)
      )
    end
  ) as charged_amount,
  coalesce((
    select sum(pa.amount)
    from public.payment_allocations pa
    join public.payments p on p.id = pa.payment_id
    where pa.charge_id = c.id
      and p.status = 'CONFIRMED'
  ), 0) as paid_amount,
  sum(
    case
      when c.status in ('CANCELLED','WAIVED') then 0
      else greatest(
        0,
        c.amount + coalesce((
          select sum(
            case
              when ca.type in ('DISCOUNT','WAIVER','REVERSAL') then -ca.amount
              when ca.type in ('SURCHARGE','CORRECTION') then ca.amount
              else 0
            end
          )
          from public.charge_adjustments ca
          where ca.charge_id = c.id
        ), 0)
      )
    end
  ) - coalesce((
    select sum(pa.amount)
    from public.payment_allocations pa
    join public.payments p on p.id = pa.payment_id
    where pa.charge_id = c.id
      and p.status = 'CONFIRMED'
  ), 0) as balance_amount
from public.charges c
group by c.school_id, c.student_id;

create or replace function private.refresh_payment_related_charges()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  charge_uuid uuid;
begin
  for charge_uuid in
    select distinct pa.charge_id
    from public.payment_allocations pa
    where pa.payment_id = coalesce(new.id, old.id)
  loop
    perform private.refresh_charge_status(charge_uuid);
  end loop;
  return coalesce(new, old);
end;
$$;

create trigger trg_payment_status_refresh
after update of status on public.payments
for each row execute function private.refresh_payment_related_charges();
