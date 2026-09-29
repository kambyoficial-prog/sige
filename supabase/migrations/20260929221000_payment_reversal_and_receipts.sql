-- SIGE 0033 — payment reversal and receipt commands
--
-- A reversal is a financial command, never a generic row mutation.
-- Reversing a payment removes it from confirmed settlement calculations while
-- preserving the original payment and its audit history.

create or replace function public.reverse_payment(
  p_payment_id uuid,
  p_reason text,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  student_id uuid;
  current_status public.payment_status;
  payment_amount numeric(12,2);
  reversal_id uuid;
  result jsonb;
  command_state jsonb;
  allocated_amount numeric(12,2);
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'REVERSAL_REASON_REQUIRED';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
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

  if current_status <> 'CONFIRMED' then
    raise exception 'PAYMENT_NOT_REVERSIBLE';
  end if;

  select coalesce(sum(pa.amount),0)
    into allocated_amount
  from public.payment_allocations pa
  where pa.payment_id = p_payment_id;

  if allocated_amount > payment_amount then
    raise exception 'PAYMENT_ALLOCATION_CORRUPTED';
  end if;

  command_state := private.begin_command(
    'reverse_payment', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.payment_reversals (
    payment_id, amount, reason, reversed_at, reversed_by
  )
  values (
    p_payment_id, payment_amount, trim(p_reason), now(), actor
  )
  returning id into reversal_id;

  update public.payments
  set status = 'REVERSED', updated_at = now()
  where id = p_payment_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id,
    before_data, after_data, reason
  )
  values (
    school_id, actor, 'REVERSE_PAYMENT', 'payment', p_payment_id,
    jsonb_build_object('status', current_status),
    jsonb_build_object(
      'status', 'REVERSED',
      'reversal_id', reversal_id,
      'amount', payment_amount
    ),
    trim(p_reason)
  );

  result := jsonb_build_object(
    'payment_id', p_payment_id,
    'student_id', student_id,
    'amount', payment_amount,
    'status', 'REVERSED',
    'reversal_id', reversal_id
  );

  perform private.complete_command(
    'reverse_payment', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.issue_receipt(
  p_payment_id uuid,
  p_receipt_number text,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  payment_status_value public.payment_status;
  receipt_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_receipt_number is null or length(trim(p_receipt_number)) < 1 then
    raise exception 'RECEIPT_NUMBER_REQUIRED';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  select p.school_id, p.status
    into school_id, payment_status_value
  from public.payments p
  where p.id = p_payment_id
  for share;

  if school_id is null then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;

  if payment_status_value <> 'CONFIRMED' then
    raise exception 'RECEIPT_REQUIRES_CONFIRMED_PAYMENT';
  end if;

  if not (select private.has_permission('finance.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'issue_receipt', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.receipts (
    school_id, payment_id, receipt_number, issued_at, issued_by
  )
  values (
    school_id, p_payment_id, trim(p_receipt_number), now(), actor
  )
  returning id into receipt_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'ISSUE_RECEIPT', 'receipt', receipt_id,
    jsonb_build_object(
      'payment_id', p_payment_id,
      'receipt_number', trim(p_receipt_number)
    )
  );

  result := jsonb_build_object(
    'receipt_id', receipt_id,
    'payment_id', p_payment_id,
    'receipt_number', trim(p_receipt_number)
  );

  perform private.complete_command(
    'issue_receipt', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.reverse_payment(uuid,text,text,text) from public;
revoke all on function public.issue_receipt(uuid,text,text,text) from public;

grant execute on function public.reverse_payment(uuid,text,text,text) to authenticated;
grant execute on function public.issue_receipt(uuid,text,text,text) to authenticated;

comment on function public.reverse_payment(uuid,text,text,text) is
  'Reverses a confirmed payment atomically and preserves the original financial event and audit history.';

comment on function public.issue_receipt(uuid,text,text,text) is
  'Issues one immutable receipt for a confirmed payment.';
