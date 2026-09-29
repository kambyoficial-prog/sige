begin;

select plan(6);

select ok(
  exists (
    select 1
    from information_schema.tables
    where table_schema='private'
      and table_name='command_idempotency'
  ),
  'private command idempotency registry exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conname='command_idempotency_actor_auth_user_id_command_name_idempotency_key_key'
  ),
  'command idempotency key is unique per actor and command'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema='private'
      and table_name='command_idempotency'
      and grantee in ('anon','authenticated')
  ),
  'command idempotency registry is not exposed through table grants'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='private'
      and table_name='command_idempotency'
      and column_name='request_hash'
  ),
  'command stores canonical request hash'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='private'
      and table_name='command_idempotency'
      and column_name='result_payload'
  ),
  'command stores deterministic result payload'
);

select ok(
  exists (
    select 1
    from information_schema.check_constraints
    where constraint_name='command_idempotency_status_check'
  ),
  'command status has explicit state machine'
);

select * from finish();
rollback;
