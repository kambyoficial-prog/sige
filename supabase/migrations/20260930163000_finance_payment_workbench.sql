-- SIGE — Secretariat payment verification workbench

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

create or replace function public.issue_receipt(
  p_payment_id uuid, p_receipt_number text default null,
  p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid := (select auth.uid()); v_school_id uuid; v_status public.payment_status;
v_receipt_id uuid; v_receipt_number text; v_next bigint; state jsonb; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 select p.school_id,p.status into v_school_id,v_status from public.payments p where p.id=p_payment_id for update;
 if v_school_id is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
 if v_status <> 'CONFIRMED' then raise exception 'RECEIPT_REQUIRES_CONFIRMED_PAYMENT'; end if;
 if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
 state:=private.begin_command('issue_receipt',v_school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 select r.id,r.receipt_number into v_receipt_id,v_receipt_number from public.receipts r where r.payment_id=p_payment_id;
 if v_receipt_id is null then
   insert into public.school_receipt_sequences(school_id,next_number) values(v_school_id,2)
   on conflict (school_id) do update set next_number=public.school_receipt_sequences.next_number+1,updated_at=now()
   returning next_number-1 into v_next;
   if nullif(trim(p_receipt_number),'') is null or upper(trim(p_receipt_number))='AUTO' then
     v_receipt_number:=format('REC-%s-%06s',extract(year from now())::int,v_next);
   else v_receipt_number:=trim(p_receipt_number); end if;
   insert into public.receipts(school_id,payment_id,receipt_number,issued_at,issued_by)
   values(v_school_id,p_payment_id,v_receipt_number,now(),actor) returning id into v_receipt_id;
   insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
   values(v_school_id,actor,'ISSUE_RECEIPT','receipt',v_receipt_id,jsonb_build_object('payment_id',p_payment_id,'receipt_number',v_receipt_number));
 end if;
 result:=jsonb_build_object('receipt_id',v_receipt_id,'payment_id',p_payment_id,'receipt_number',v_receipt_number);
 perform private.complete_command('issue_receipt',v_school_id,p_idempotency_key,result);
 return result;
end $$;

revoke all on function public.issue_receipt(uuid,text,text,text) from public;
grant execute on function public.issue_receipt(uuid,text,text,text) to authenticated;

create or replace function public.get_finance_payment_workbench()
returns jsonb language sql stable security definer set search_path=''
as $$
 select coalesce(jsonb_agg(row_to_json(x) order by x.created_at desc),'[]'::jsonb)
 from (
   select p.id,p.student_id,sd.school_number,sd.full_name as student_name,p.amount,p.method,p.status,
          p.paid_at,p.confirmed_at,p.external_reference,p.notes,p.created_at,
          coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0) allocated_amount,
          greatest(p.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0),0) unallocated_amount,
          (select r.receipt_number from public.receipts r where r.payment_id=p.id limit 1) receipt_number,
          coalesce((select jsonb_agg(jsonb_build_object(
            'id',c.id,'description',c.description,'due_on',c.due_on,'amount',c.amount,
            'allocated_amount',coalesce((select sum(pa2.amount) from public.payment_allocations pa2 where pa2.charge_id=c.id),0),
            'remaining_amount',greatest(c.amount-coalesce((select sum(pa3.amount) from public.payment_allocations pa3 where pa3.charge_id=c.id),0),0)
          ) order by c.due_on,c.created_at)
          from public.charges c where c.student_id=p.student_id and c.status<>'CANCELLED'
          and c.amount-coalesce((select sum(pa4.amount) from public.payment_allocations pa4 where pa4.charge_id=c.id),0)>0),'[]'::jsonb) charges
   from public.payments p
   join public.student_directory sd on sd.id=p.student_id
   where private.has_permission('finance.manage',p.school_id)
 ) x;
$$;
revoke all on function public.get_finance_payment_workbench() from public;
grant execute on function public.get_finance_payment_workbench() to authenticated;
