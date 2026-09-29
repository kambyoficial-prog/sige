-- SIGE 0018 — Transactional payment commands
--
-- Payment lifecycle:
--   record -> PENDING
--   confirm -> CONFIRMED
--   allocate -> links confirmed payment to concrete charges
--
-- These operations are intentionally separate so bank/mobile-money payments
-- can exist before confirmation and one confirmed payment can settle several
-- obligations.

create or replace function public.record_payment(
  p_student_id uuid,
  p_amount numeric(12,2),
  p_method public.payment_method,
  p_paid_at timestamptz default now(),
  p_external_reference text default null,
  p_notes text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  payment_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_amount <= 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  select s.school_id
    into school_id
  from public.students s
  where s.id = p_student_id
    and s.status = 'ACTIVE'
  for share;

  if school_id is null then
    raise exception 'STUDENT_NOT_FOUND';
  end if;

  if not (select private.has_permission('finance.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  command_state := private.begin_command(
    'record_payment',
    school_id,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.payments (
    school_id,
    student_id,
    amount,
    method,
    status,
    paid_at,
    external_reference,
    notes
  )
  values (
    school_id,
    p_student_id,
    p_amount,
    p_method,
    'PENDING',
    p_paid_at,
    nullif(trim(p_external_reference), ''),
    p_notes
  )
  returning id into payment_id;

  insert into public.audit_events (
    school_id,
    actor_auth_user_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    school_id,
    actor,
    'RECORD_PAYMENT',
    'payment',
    payment_id,
    jsonb_build_object(
      'student_id', p_student_id,
      'amount', p_amount,
      'method', p_method,
      'status', 'PENDING',
      'external_reference', p_external_reference
    )
  );

  result := jsonb_build_object(
    'payment_id', payment_id,
    'student_id', p_student_id,
    'amount', p_amount,
    'status', 'PENDING'
  );

  perform private.complete_command(
    'record_payment',
    school_id,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

create or replace function public.confirm_payment(
  p_payment_id uuid,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  student_id uuid;
  current_status public.payment_status;
  payment_amount numeric(12,2);
  confirmed_at timestamptz;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select p.school_id, p.student_id, p.status, p.amount
    into school_id, student_id, current_status, payment_amount
  from public.payments p
  where p.id = p_payment_id
  for update;

  if school_id is null then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;

  if not (select private.has_permission('finance.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  command_state := private.begin_command(
    'confirm_payment',
    school_id,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  if current_status = 'CONFIRMED' then
    raise exception 'PAYMENT_ALREADY_CONFIRMED';
  end if;

  if current_status <> 'PENDING' then
    raise exception 'PAYMENT_NOT_CONFIRMABLE';
  end if;

  confirmed_at := now();

  update public.payments
     set status = 'CONFIRMED',
         confirmed_at = confirmed_at,
         confirmed_by = actor
   where id = p_payment_id;

  insert into public.audit_events (
    school_id,
    actor_auth_user_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  )
  values (
    school_id,
    actor,
    'CONFIRM_PAYMENT',
    'payment',
    p_payment_id,
    jsonb_build_object('status', current_status),
    jsonb_build_object(
      'status', 'CONFIRMED',
      'confirmed_at', confirmed_at,
      'confirmed_by', actor
    )
  );

  result := jsonb_build_object(
    'payment_id', p_payment_id,
    'student_id', student_id,
    'amount', payment_amount,
    'status', 'CONFIRMED',
    'confirmed_at', confirmed_at
  );

  perform private.complete_command(
    'confirm_payment',
    school_id,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

create or replace function public.allocate_payment(
  p_payment_id uuid,
  p_charge_id uuid,
  p_amount numeric(12,2),
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  payment_school uuid;
  payment_student uuid;
  payment_status_value public.payment_status;
  charge_school uuid;
  charge_student uuid;
  allocation_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_amount <= 0 then
    raise exception 'INVALID_ALLOCATION_AMOUNT';
  end if;

  select p.school_id, p.student_id, p.status
    into payment_school, payment_student, payment_status_value
  from public.payments p
  where p.id = p_payment_id
  for update;

  if payment_school is null then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;

  if payment_status_value <> 'CONFIRMED' then
    raise exception 'PAYMENT_NOT_CONFIRMED';
  end if;

  select c.school_id, c.student_id
    into charge_school, charge_student
  from public.charges c
  where c.id = p_charge_id
  for update;

  if charge_school is null then
    raise exception 'CHARGE_NOT_FOUND';
  end if;

  if payment_school <> charge_school or payment_student <> charge_student then
    raise exception 'PAYMENT_CHARGE_CONTEXT_MISMATCH';
  end if;

  if not (select private.has_permission('finance.manage', payment_school)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  command_state := private.begin_command(
    'allocate_payment',
    payment_school,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.payment_allocations (
    payment_id,
    charge_id,
    amount
  )
  values (
    p_payment_id,
    p_charge_id,
    p_amount
  )
  returning id into allocation_id;

  insert into public.audit_events (
    school_id,
    actor_auth_user_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    payment_school,
    actor,
    'ALLOCATE_PAYMENT',
    'payment_allocation',
    allocation_id,
    jsonb_build_object(
      'payment_id', p_payment_id,
      'charge_id', p_charge_id,
      'amount', p_amount
    )
  );

  result := jsonb_build_object(
    'allocation_id', allocation_id,
    'payment_id', p_payment_id,
    'charge_id', p_charge_id,
    'amount', p_amount
  );

  perform private.complete_command(
    'allocate_payment',
    payment_school,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

revoke all on function public.record_payment(uuid, numeric, public.payment_method, timestamptz, text, text, text, text) from public;
revoke all on function public.confirm_payment(uuid, text, text) from public;
revoke all on function public.allocate_payment(uuid, uuid, numeric, text, text) from public;

grant execute on function public.record_payment(uuid, numeric, public.payment_method, timestamptz, text, text, text, text) to authenticated;
grant execute on function public.confirm_payment(uuid, text, text) to authenticated;
grant execute on function public.allocate_payment(uuid, uuid, numeric, text, text) to authenticated;

-- Critical financial mutations must go through commands, not generic Data API CRUD.
revoke insert, update, delete on public.payments from authenticated;
revoke insert, update, delete on public.payment_allocations from authenticated;
revoke insert, update, delete on public.payment_reversals from authenticated;
revoke insert, update, delete on public.receipts from authenticated;

grant select on public.payments to authenticated;
grant select on public.payment_allocations to authenticated;
grant select on public.payment_reversals to authenticated;
grant select on public.receipts to authenticated;
