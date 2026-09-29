-- SIGE F7 — finance command boundary and read models
-- Applied to the SIGE Supabase project as migration f7_finance_command_boundary_and_read_models.
-- This source file mirrors the applied migration.

-- Finance mutations are command-only. Read access remains RLS-scoped.
revoke insert,update,delete on public.fee_types,public.fee_plans,public.fee_plan_items,public.transport_services,public.student_services,public.charges,public.charge_adjustments from authenticated;
grant select on public.fee_types,public.fee_plans,public.fee_plan_items,public.transport_services,public.student_services,public.charges,public.charge_adjustments to authenticated;

drop policy if exists finance_read_fee_types on public.fee_types;
create policy finance_read_fee_types on public.fee_types for select to authenticated using(private.has_permission('finance.read',school_id) or private.has_permission('finance.manage',school_id));
drop policy if exists finance_read_fee_plans on public.fee_plans;
create policy finance_read_fee_plans on public.fee_plans for select to authenticated using(private.has_permission('finance.read',school_id) or private.has_permission('finance.manage',school_id));
drop policy if exists finance_read_transport_services on public.transport_services;
create policy finance_read_transport_services on public.transport_services for select to authenticated using(private.has_permission('finance.read',school_id) or private.has_permission('finance.manage',school_id));
drop policy if exists finance_read_charges on public.charges;
create policy finance_read_charges on public.charges for select to authenticated using(private.has_permission('finance.read',school_id) or private.has_permission('finance.manage',school_id));
drop policy if exists finance_read_fee_plan_items on public.fee_plan_items;
create policy finance_read_fee_plan_items on public.fee_plan_items for select to authenticated using(exists(select 1 from public.fee_plans fp where fp.id=fee_plan_id and (private.has_permission('finance.read',fp.school_id) or private.has_permission('finance.manage',fp.school_id))));
drop policy if exists finance_read_student_services on public.student_services;
create policy finance_read_student_services on public.student_services for select to authenticated using(exists(select 1 from public.students s where s.id=student_id and (private.has_permission('finance.read',s.school_id) or private.has_permission('finance.manage',s.school_id))));
drop policy if exists finance_read_charge_adjustments on public.charge_adjustments;
create policy finance_read_charge_adjustments on public.charge_adjustments for select to authenticated using(exists(select 1 from public.charges c where c.id=charge_id and (private.has_permission('finance.read',c.school_id) or private.has_permission('finance.manage',c.school_id))));

create or replace function public.create_fee_type(p_school_id uuid,p_code text,p_name text,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); id uuid; result jsonb; state jsonb; begin
if actor is null then raise exception 'AUTH_REQUIRED'; end if; if not private.has_permission('finance.manage',p_school_id) then raise exception 'FORBIDDEN'; end if;
if nullif(trim(p_code),'') is null or nullif(trim(p_name),'') is null then raise exception 'FEE_TYPE_REQUIRED'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('create_fee_type',p_school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.fee_types(school_id,code,name) values(p_school_id,trim(p_code),trim(p_name)) returning id into id;
result=jsonb_build_object('fee_type_id',id); perform private.complete_command('create_fee_type',p_school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.create_fee_plan(p_school_id uuid,p_academic_year_id uuid,p_code text,p_name text,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); id uuid; ys uuid; result jsonb; state jsonb; begin
if actor is null then raise exception 'AUTH_REQUIRED'; end if; if not private.has_permission('finance.manage',p_school_id) then raise exception 'FORBIDDEN'; end if;
select school_id into ys from public.academic_years where id=p_academic_year_id; if ys is null or ys<>p_school_id then raise exception 'FEE_PLAN_YEAR_SCHOOL_MISMATCH'; end if;
if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('create_fee_plan',p_school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.fee_plans(school_id,academic_year_id,code,name) values(p_school_id,p_academic_year_id,trim(p_code),trim(p_name)) returning id into id;
result=jsonb_build_object('fee_plan_id',id); perform private.complete_command('create_fee_plan',p_school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.add_fee_plan_item(p_fee_plan_id uuid,p_fee_type_id uuid,p_amount numeric,p_due_day integer default null,p_sequence_no integer default null,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; id uuid; result jsonb; state jsonb; begin
select school_id into school_id from public.fee_plans where id=p_fee_plan_id; if school_id is null then raise exception 'FEE_PLAN_NOT_FOUND'; end if;
if not private.has_permission('finance.manage',school_id) then raise exception 'FORBIDDEN'; end if; if p_amount<0 then raise exception 'INVALID_FEE_AMOUNT'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('add_fee_plan_item',school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.fee_plan_items(fee_plan_id,fee_type_id,amount,due_day,sequence_no) values(p_fee_plan_id,p_fee_type_id,p_amount,p_due_day,p_sequence_no) returning id into id;
result=jsonb_build_object('fee_plan_item_id',id); perform private.complete_command('add_fee_plan_item',school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.create_transport_service(p_school_id uuid,p_code text,p_name text,p_route text default null,p_stop text default null,p_amount numeric default null,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); id uuid; result jsonb; state jsonb; begin
if actor is null then raise exception 'AUTH_REQUIRED'; end if; if not private.has_permission('finance.manage',p_school_id) then raise exception 'FORBIDDEN'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('create_transport_service',p_school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.transport_services(school_id,code,name,route,stop,amount) values(p_school_id,trim(p_code),trim(p_name),nullif(trim(p_route),''),nullif(trim(p_stop),''),p_amount) returning id into id;
result=jsonb_build_object('transport_service_id',id); perform private.complete_command('create_transport_service',p_school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.assign_student_transport(p_student_id uuid,p_academic_year_id uuid,p_transport_service_id uuid,p_starts_on date default null,p_ends_on date default null,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; ss uuid; id uuid; result jsonb; state jsonb; begin
select s.school_id into school_id from public.students s where s.id=p_student_id; select t.school_id into ss from public.transport_services t where t.id=p_transport_service_id;
if school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if; if ss is null or ss<>school_id then raise exception 'TRANSPORT_SERVICE_SCHOOL_MISMATCH'; end if;
if not private.has_permission('finance.manage',school_id) then raise exception 'FORBIDDEN'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('assign_student_transport',school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.student_services(student_id,academic_year_id,service_type,transport_service_id,starts_on,ends_on) values(p_student_id,p_academic_year_id,'TRANSPORT',p_transport_service_id,p_starts_on,p_ends_on) returning id into id;
result=jsonb_build_object('student_service_id',id); perform private.complete_command('assign_student_transport',school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.create_charge(p_student_id uuid,p_academic_year_id uuid,p_amount numeric,p_due_on date,p_fee_type_id uuid default null,p_description text default null,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; ys uuid; fs uuid; id uuid; result jsonb; state jsonb; begin
select s.school_id into school_id from public.students s where s.id=p_student_id and s.status='ACTIVE'; select school_id into ys from public.academic_years where id=p_academic_year_id;
if school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if; if ys is null or ys<>school_id then raise exception 'CHARGE_YEAR_SCHOOL_MISMATCH'; end if;
if p_fee_type_id is not null then select school_id into fs from public.fee_types where id=p_fee_type_id; if fs is null or fs<>school_id then raise exception 'CHARGE_FEE_TYPE_SCHOOL_MISMATCH'; end if; end if;
if not private.has_permission('finance.manage',school_id) then raise exception 'FORBIDDEN'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('create_charge',school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.charges(school_id,student_id,fee_type_id,amount,due_on,description,academic_year_id) values(school_id,p_student_id,p_fee_type_id,p_amount,nullif(p_due_on,'infinity'),nullif(trim(p_description),''),p_academic_year_id) returning id into id;
result=jsonb_build_object('charge_id',id); perform private.complete_command('create_charge',school_id,p_idempotency_key,result); return result; end $$;

create or replace function public.adjust_charge(p_charge_id uuid,p_type public.charge_adjustment_type,p_amount numeric,p_reason text,p_idempotency_key text default null,p_request_hash text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; id uuid; result jsonb; state jsonb; begin
select school_id into school_id from public.charges where id=p_charge_id; if school_id is null then raise exception 'CHARGE_NOT_FOUND'; end if;
if not private.has_permission('finance.manage',school_id) then raise exception 'FORBIDDEN'; end if; if p_amount<=0 or nullif(trim(p_reason),'') is null then raise exception 'INVALID_CHARGE_ADJUSTMENT'; end if; if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
state:=private.begin_command('adjust_charge',school_id,p_idempotency_key,p_request_hash); if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
insert into public.charge_adjustments(charge_id,type,amount,reason,created_by) values(p_charge_id,p_type,p_amount,trim(p_reason),actor) returning id into id;
result=jsonb_build_object('adjustment_id',id); perform private.complete_command('adjust_charge',school_id,p_idempotency_key,result); return result; end $$;

drop view if exists public.finance_charge_directory;
create view public.finance_charge_directory with(security_invoker=true) as
select c.id,c.school_id,c.student_id,pe.full_name student_name,c.academic_year_id,ay.label academic_year,c.fee_type_id,ft.name fee_type,c.amount,c.due_on,c.status,c.description,private.charge_effective_amount(c.id) effective_amount,
coalesce((select sum(pa.amount) from public.payment_allocations pa join public.payments p on p.id=pa.payment_id where pa.charge_id=c.id and p.status='CONFIRMED'),0) paid_amount
from public.charges c join public.students s on s.id=c.student_id join public.people pe on pe.id=s.person_id join public.academic_years ay on ay.id=c.academic_year_id left join public.fee_types ft on ft.id=c.fee_type_id;
drop view if exists public.finance_payment_directory;
create view public.finance_payment_directory with(security_invoker=true) as
select p.id,p.school_id,p.student_id,pe.full_name student_name,p.amount,p.method,p.status,p.paid_at,p.confirmed_at,p.external_reference,p.notes,r.receipt_number,
coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0) allocated_amount
from public.payments p join public.students s on s.id=p.student_id join public.people pe on pe.id=s.person_id left join public.receipts r on r.payment_id=p.id;
grant select on public.finance_charge_directory,public.finance_payment_directory to authenticated;
revoke all on function public.create_fee_type(uuid,text,text,text,text),public.create_fee_plan(uuid,uuid,text,text,text,text),public.add_fee_plan_item(uuid,uuid,numeric,integer,integer,text,text),public.create_transport_service(uuid,text,text,text,text,numeric,text,text),public.assign_student_transport(uuid,uuid,uuid,date,date,text,text),public.create_charge(uuid,uuid,numeric,date,uuid,text,text,text),public.adjust_charge(uuid,public.charge_adjustment_type,numeric,text,text,text) from public;
grant execute on function public.create_fee_type(uuid,text,text,text,text),public.create_fee_plan(uuid,uuid,text,text,text,text),public.add_fee_plan_item(uuid,uuid,numeric,integer,integer,text,text),public.create_transport_service(uuid,text,text,text,text,numeric,text,text),public.assign_student_transport(uuid,uuid,uuid,date,date,text,text),public.create_charge(uuid,uuid,numeric,date,uuid,text,text,text),public.adjust_charge(uuid,public.charge_adjustment_type,numeric,text,text,text) to authenticated;