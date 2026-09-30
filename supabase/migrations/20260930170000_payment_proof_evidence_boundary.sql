-- SIGE — Payment proof evidence, verification boundary and receipt hardening
--
-- Payment evidence lives outside the relational database in a private Storage
-- bucket. The database stores the authoritative metadata and verification state.
-- Storage objects are accessed only through the Storage API.

do $$ begin
  create type public.payment_proof_status as enum ('UPLOADING','READY','VERIFIED','REJECTED');
exception when duplicate_object then null;
end $$;

create table if not exists public.payment_proofs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  storage_bucket text not null default 'payment-proofs',
  storage_path text not null unique,
  original_filename text not null,
  content_type text not null,
  byte_size bigint not null,
  status public.payment_proof_status not null default 'UPLOADING',
  rejection_reason text,
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_proofs_filename_ck check (length(trim(original_filename)) between 1 and 255),
  constraint payment_proofs_type_ck check (content_type in ('application/pdf','image/jpeg','image/png')),
  constraint payment_proofs_size_ck check (byte_size > 0 and byte_size <= 10485760)
);

alter table public.payment_proofs enable row level security;
drop policy if exists payment_proofs_read on public.payment_proofs;
create policy payment_proofs_read on public.payment_proofs
for select to authenticated
using (private.has_permission('finance.manage', school_id));
revoke insert, update, delete on public.payment_proofs from authenticated;
grant select on public.payment_proofs to authenticated;

create index if not exists payment_proofs_payment_idx on public.payment_proofs(payment_id, created_at desc);
create index if not exists payment_proofs_school_status_idx on public.payment_proofs(school_id, status, created_at desc);

create or replace function public.create_payment_proof_upload(
  p_payment_id uuid,p_original_filename text,p_content_type text,p_byte_size bigint,
  p_idempotency_key text default null,p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); v_school_id uuid; v_status public.payment_status;
v_proof_id uuid := gen_random_uuid(); v_filename text; v_path text; state jsonb; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 if p_content_type not in ('application/pdf','image/jpeg','image/png') then raise exception 'PAYMENT_PROOF_TYPE_NOT_ALLOWED'; end if;
 if p_byte_size <= 0 or p_byte_size > 10485760 then raise exception 'PAYMENT_PROOF_SIZE_NOT_ALLOWED'; end if;
 select p.school_id,p.status into v_school_id,v_status from public.payments p where p.id=p_payment_id for update;
 if v_school_id is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
 if v_status='REVERSED' then raise exception 'PAYMENT_PROOF_REQUIRES_ACTIVE_PAYMENT'; end if;
 if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
 state:=private.begin_command('create_payment_proof_upload',v_school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 v_filename:=regexp_replace(lower(coalesce(nullif(trim(p_original_filename),''),'comprovativo')),'[^a-z0-9._-]+','-','g');
 v_path:=format('payments/%s/%s-%s',p_payment_id,v_proof_id,v_filename);
 insert into public.payment_proofs(id,school_id,payment_id,storage_bucket,storage_path,original_filename,content_type,byte_size,uploaded_by)
 values(v_proof_id,v_school_id,p_payment_id,'payment-proofs',v_path,left(trim(p_original_filename),255),p_content_type,p_byte_size,actor);
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
 values(v_school_id,actor,'CREATE_PAYMENT_PROOF','payment_proof',v_proof_id,
   jsonb_build_object('payment_id',p_payment_id,'storage_path',v_path,'content_type',p_content_type,'byte_size',p_byte_size));
 result:=jsonb_build_object('proof_id',v_proof_id,'payment_id',p_payment_id,'bucket','payment-proofs','path',v_path,'status','UPLOADING');
 perform private.complete_command('create_payment_proof_upload',v_school_id,p_idempotency_key,result);
 return result;
end $$;
revoke all on function public.create_payment_proof_upload(uuid,text,text,bigint,text,text) from public;
grant execute on function public.create_payment_proof_upload(uuid,text,text,bigint,text,text) to authenticated;

create or replace function public.finalize_payment_proof(p_proof_id uuid,p_idempotency_key text default null,p_request_hash text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); v_school_id uuid; v_payment_id uuid; v_bucket text; v_path text;
v_status public.payment_proof_status; v_object_exists boolean; state jsonb; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 select school_id,payment_id,storage_bucket,storage_path,status into v_school_id,v_payment_id,v_bucket,v_path,v_status
 from public.payment_proofs where id=p_proof_id for update;
 if v_school_id is null then raise exception 'PAYMENT_PROOF_NOT_FOUND'; end if;
 if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
 state:=private.begin_command('finalize_payment_proof',v_school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 if v_status in ('READY','VERIFIED') then
   result:=jsonb_build_object('proof_id',p_proof_id,'payment_id',v_payment_id,'status',v_status);
   perform private.complete_command('finalize_payment_proof',v_school_id,p_idempotency_key,result); return result;
 end if;
 select exists(select 1 from storage.objects o where o.bucket_id=v_bucket and o.name=v_path) into v_object_exists;
 if not v_object_exists then raise exception 'PAYMENT_PROOF_OBJECT_NOT_FOUND'; end if;
 update public.payment_proofs set status='READY',updated_at=now() where id=p_proof_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
 values(v_school_id,actor,'FINALIZE_PAYMENT_PROOF','payment_proof',p_proof_id,jsonb_build_object('payment_id',v_payment_id,'status','READY'));
 result:=jsonb_build_object('proof_id',p_proof_id,'payment_id',v_payment_id,'status','READY');
 perform private.complete_command('finalize_payment_proof',v_school_id,p_idempotency_key,result); return result;
end $$;
revoke all on function public.finalize_payment_proof(uuid,text,text) from public;
grant execute on function public.finalize_payment_proof(uuid,text,text) to authenticated;

create or replace function public.verify_payment_proof(
  p_proof_id uuid,p_status public.payment_proof_status,p_rejection_reason text default null,
  p_idempotency_key text default null,p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); v_school_id uuid; v_payment_id uuid; v_current public.payment_proof_status;
state jsonb; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 if p_status not in ('VERIFIED','REJECTED') then raise exception 'PAYMENT_PROOF_INVALID_VERIFICATION_STATUS'; end if;
 if p_status='REJECTED' and nullif(trim(p_rejection_reason),'') is null then raise exception 'PAYMENT_PROOF_REJECTION_REASON_REQUIRED'; end if;
 select school_id,payment_id,status into v_school_id,v_payment_id,v_current from public.payment_proofs where id=p_proof_id for update;
 if v_school_id is null then raise exception 'PAYMENT_PROOF_NOT_FOUND'; end if;
 if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
 if v_current not in ('READY','REJECTED') then raise exception 'PAYMENT_PROOF_NOT_READY'; end if;
 state:=private.begin_command('verify_payment_proof',v_school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 update public.payment_proofs set status=p_status,
   rejection_reason=case when p_status='REJECTED' then nullif(trim(p_rejection_reason),'') else null end,
   verified_by=actor,verified_at=now(),updated_at=now() where id=p_proof_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(v_school_id,actor,'VERIFY_PAYMENT_PROOF','payment_proof',p_proof_id,
   jsonb_build_object('status',v_current),jsonb_build_object('payment_id',v_payment_id,'status',p_status),
   nullif(trim(p_rejection_reason),''));
 result:=jsonb_build_object('proof_id',p_proof_id,'payment_id',v_payment_id,'status',p_status);
 perform private.complete_command('verify_payment_proof',v_school_id,p_idempotency_key,result); return result;
end $$;
revoke all on function public.verify_payment_proof(uuid,public.payment_proof_status,text,text,text) from public;
grant execute on function public.verify_payment_proof(uuid,public.payment_proof_status,text,text,text) to authenticated;

create or replace function public.get_payment_proof(p_proof_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$ select to_jsonb(x) from (
 select pp.id,pp.payment_id,pp.storage_bucket as bucket,pp.storage_path as path,pp.original_filename,
 pp.content_type,pp.byte_size,pp.status,pp.rejection_reason,pp.uploaded_at,pp.verified_at
 from public.payment_proofs pp where pp.id=p_proof_id and private.has_permission('finance.manage',pp.school_id)
) x $$;
revoke all on function public.get_payment_proof(uuid) from public;
grant execute on function public.get_payment_proof(uuid) to authenticated;

create or replace function public.confirm_payment(p_payment_id uuid,p_idempotency_key text default null,p_request_hash text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); school_id uuid; student_id uuid; current_status public.payment_status;
payment_amount numeric(12,2); confirmed_at timestamptz; proof_required boolean; verified_proofs integer;
result jsonb; command_state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 select p.school_id,p.student_id,p.status,p.amount into school_id,student_id,current_status,payment_amount
 from public.payments p where p.id=p_payment_id for update;
 if school_id is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
 if not (select private.has_permission('finance.manage',school_id)) then raise exception 'FORBIDDEN'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 command_state:=private.begin_command('confirm_payment',school_id,p_idempotency_key,p_request_hash);
 if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
 if current_status='CONFIRMED' then raise exception 'PAYMENT_ALREADY_CONFIRMED'; end if;
 if current_status<>'PENDING' then raise exception 'PAYMENT_NOT_CONFIRMABLE'; end if;
 select p.method <> 'CASH' into proof_required from public.payments p where p.id=p_payment_id;
 select count(*) into verified_proofs from public.payment_proofs where payment_id=p_payment_id and status='VERIFIED';
 if proof_required and verified_proofs=0 then raise exception 'PAYMENT_PROOF_REQUIRED_BEFORE_CONFIRMATION'; end if;
 confirmed_at:=now();
 update public.payments set status='CONFIRMED',confirmed_at=confirmed_at,confirmed_by=actor where id=p_payment_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,before_data,after_data)
 values(school_id,actor,'CONFIRM_PAYMENT','payment',p_payment_id,jsonb_build_object('status',current_status),
 jsonb_build_object('status','CONFIRMED','confirmed_at',confirmed_at,'confirmed_by',actor));
 result:=jsonb_build_object('payment_id',p_payment_id,'student_id',student_id,'amount',payment_amount,'status','CONFIRMED','confirmed_at',confirmed_at);
 perform private.complete_command('confirm_payment',school_id,p_idempotency_key,result); return result;
end $$;
revoke all on function public.confirm_payment(uuid,text,text) from public;
grant execute on function public.confirm_payment(uuid,text,text) to authenticated;

create or replace function public.issue_receipt(p_payment_id uuid,p_receipt_number text default null,p_idempotency_key text default null,p_request_hash text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); v_school_id uuid; v_status public.payment_status; v_amount numeric(12,2);
v_allocated numeric(12,2); v_receipt_id uuid; v_receipt_number text; v_next bigint; state jsonb; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 select p.school_id,p.status,p.amount into v_school_id,v_status,v_amount from public.payments p where p.id=p_payment_id for update;
 if v_school_id is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
 if v_status <> 'CONFIRMED' then raise exception 'RECEIPT_REQUIRES_CONFIRMED_PAYMENT'; end if;
 if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
 select coalesce(sum(pa.amount),0) into v_allocated from public.payment_allocations pa where pa.payment_id=p_payment_id;
 if v_allocated <> v_amount then raise exception 'RECEIPT_REQUIRES_FULL_ALLOCATION'; end if;
 state:=private.begin_command('issue_receipt',v_school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 select r.id,r.receipt_number into v_receipt_id,v_receipt_number from public.receipts r where r.payment_id=p_payment_id;
 if v_receipt_id is null then
   insert into public.school_receipt_sequences(school_id,next_number) values(v_school_id,2)
   on conflict(school_id) do update set next_number=public.school_receipt_sequences.next_number+1,updated_at=now()
   returning next_number-1 into v_next;
   if nullif(trim(p_receipt_number),'') is null or upper(trim(p_receipt_number))='AUTO' then v_receipt_number:=format('REC-%s-%06s',extract(year from now())::int,v_next); else v_receipt_number:=trim(p_receipt_number); end if;
   insert into public.receipts(school_id,payment_id,receipt_number,issued_at,issued_by)
   values(v_school_id,p_payment_id,v_receipt_number,now(),actor) returning id into v_receipt_id;
   insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
   values(v_school_id,actor,'ISSUE_RECEIPT','receipt',v_receipt_id,jsonb_build_object('payment_id',p_payment_id,'receipt_number',v_receipt_number,'amount',v_amount));
 end if;
 result:=jsonb_build_object('receipt_id',v_receipt_id,'payment_id',p_payment_id,'receipt_number',v_receipt_number);
 perform private.complete_command('issue_receipt',v_school_id,p_idempotency_key,result); return result;
end $$;
revoke all on function public.issue_receipt(uuid,text,text,text) from public;
grant execute on function public.issue_receipt(uuid,text,text,text) to authenticated;

create or replace function public.get_finance_payment_workbench()
returns jsonb language sql stable security definer set search_path=''
as $$
 select coalesce(jsonb_agg(row_to_json(x) order by x.created_at desc),'[]'::jsonb)
 from (
   select p.id,p.student_id,sd.school_number,sd.full_name as student_name,p.amount,p.method,p.status,p.paid_at,p.confirmed_at,
          p.external_reference,p.notes,p.created_at,
          coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0) allocated_amount,
          greatest(p.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0),0) unallocated_amount,
          (select r.receipt_number from public.receipts r where r.payment_id=p.id limit 1) receipt_number,
          (p.method <> 'CASH') as proof_required,
          coalesce((select jsonb_agg(jsonb_build_object(
            'id',pp.id,'original_filename',pp.original_filename,'content_type',pp.content_type,'byte_size',pp.byte_size,
            'status',pp.status,'rejection_reason',pp.rejection_reason,'uploaded_at',pp.uploaded_at,'verified_at',pp.verified_at
          ) order by pp.created_at desc) from public.payment_proofs pp where pp.payment_id=p.id),'[]'::jsonb) proofs,
          coalesce((select jsonb_agg(jsonb_build_object(
            'id',c.id,'description',c.description,'due_on',c.due_on,'amount',c.amount,
            'allocated_amount',coalesce((select sum(pa2.amount) from public.payment_allocations pa2 where pa2.charge_id=c.id),0),
            'remaining_amount',greatest(c.amount-coalesce((select sum(pa3.amount) from public.payment_allocations pa3 where pa3.charge_id=c.id),0),0)
          ) order by c.due_on,c.created_at)
          from public.charges c where c.student_id=p.student_id and c.status<>'CANCELLED'
          and c.amount-coalesce((select sum(pa4.amount) from public.payment_allocations pa4 where pa4.charge_id=c.id),0)>0),'[]'::jsonb) charges
   from public.payments p join public.student_directory sd on sd.id=p.student_id
   where private.has_permission('finance.manage',p.school_id)
 ) x;
$$;
revoke all on function public.get_finance_payment_workbench() from public;
grant execute on function public.get_finance_payment_workbench() to authenticated;

-- Storage policies. The bucket itself is provisioned via supabase/config.toml
-- and the Storage API; the database never mutates storage metadata directly.
drop policy if exists payment_proofs_storage_insert on storage.objects;
create policy payment_proofs_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id='payment-proofs'
  and (storage.foldername(name))[1]='payments'
  and (storage.foldername(name))[2] is not null
  and exists (
    select 1 from public.payments p
    where p.id=(storage.foldername(name))[2]::uuid
      and private.has_permission('finance.manage',p.school_id)
  )
);

drop policy if exists payment_proofs_storage_select on storage.objects;
create policy payment_proofs_storage_select on storage.objects
for select to authenticated
using (
  bucket_id='payment-proofs'
  and exists (
    select 1 from public.payment_proofs pp
    where pp.storage_bucket=bucket_id and pp.storage_path=name
      and private.has_permission('finance.manage',pp.school_id)
  )
);
