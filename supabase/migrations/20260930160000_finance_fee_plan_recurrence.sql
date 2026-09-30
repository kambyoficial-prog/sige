-- SIGE — finance fee-plan recurrence and student assignment

create type public.fee_billing_frequency as enum ('ONCE','MONTHLY','QUARTERLY','ACADEMIC_YEAR');

alter table public.fee_plan_items
  add column if not exists billing_frequency public.fee_billing_frequency not null default 'ONCE',
  add column if not exists starts_on date,
  add column if not exists ends_on date;

create table if not exists public.student_fee_plan_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  student_id uuid not null references public.students(id),
  academic_year_id uuid not null references public.academic_years(id),
  fee_plan_id uuid not null references public.fee_plans(id),
  starts_on date not null,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_fee_plan_dates_chk check (ends_on is null or ends_on >= starts_on)
);

create unique index if not exists student_fee_plan_assignment_active_uq
  on public.student_fee_plan_assignments(student_id, academic_year_id) where active;
create index if not exists student_fee_plan_assignment_school_year_idx
  on public.student_fee_plan_assignments(school_id, academic_year_id, active);

alter table public.student_fee_plan_assignments enable row level security;

drop policy if exists student_fee_plan_assignment_manage on public.student_fee_plan_assignments;
create policy student_fee_plan_assignment_manage on public.student_fee_plan_assignments
for all to authenticated
using (private.has_permission('finance.manage', school_id))
with check (private.has_permission('finance.manage', school_id));

create or replace function public.assign_student_fee_plan(
  p_student_id uuid, p_academic_year_id uuid, p_fee_plan_id uuid,
  p_starts_on date, p_ends_on date default null,
  p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid := (select auth.uid());
  v_school_id uuid; v_plan_school uuid; v_plan_year uuid; v_id uuid;
  state jsonb; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select school_id into v_school_id from public.students where id=p_student_id and status='ACTIVE';
  if v_school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  select school_id, academic_year_id into v_plan_school, v_plan_year from public.fee_plans where id=p_fee_plan_id and active;
  if v_plan_school is null then raise exception 'FEE_PLAN_NOT_FOUND'; end if;
  if v_plan_school <> v_school_id or (v_plan_year is not null and v_plan_year <> p_academic_year_id) then
    raise exception 'FEE_PLAN_CONTEXT_MISMATCH';
  end if;
  if not (select private.has_permission('finance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
  state:=private.begin_command('assign_student_fee_plan',v_school_id,p_idempotency_key,p_request_hash);
  if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
  update public.student_fee_plan_assignments set active=false,updated_at=now()
    where student_id=p_student_id and academic_year_id=p_academic_year_id and active;
  insert into public.student_fee_plan_assignments
    (school_id,student_id,academic_year_id,fee_plan_id,starts_on,ends_on,active)
    values(v_school_id,p_student_id,p_academic_year_id,p_fee_plan_id,p_starts_on,p_ends_on,true)
    returning id into v_id;
  result:=jsonb_build_object('assignment_id',v_id,'student_id',p_student_id,'academic_year_id',p_academic_year_id,'fee_plan_id',p_fee_plan_id);
  perform private.complete_command('assign_student_fee_plan',v_school_id,p_idempotency_key,result);
  return result;
end $$;

create or replace function public.generate_student_fee_plan_charges(
  p_assignment_id uuid, p_until date default null,
  p_idempotency_key text default null, p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid := (select auth.uid());
  a public.student_fee_plan_assignments%rowtype;
  item record;
  v_start date; v_end date; occurrence date; due_date date;
  charge_id uuid; created_count integer:=0; state jsonb; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select * into a from public.student_fee_plan_assignments where id=p_assignment_id and active;
  if not found then raise exception 'FEE_PLAN_ASSIGNMENT_NOT_FOUND'; end if;
  if not (select private.has_permission('finance.manage',a.school_id)) then raise exception 'FORBIDDEN'; end if;
  state:=private.begin_command('generate_student_fee_plan_charges',a.school_id,p_idempotency_key,p_request_hash);
  if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
  select greatest(ay.starts_on,a.starts_on), least(ay.ends_on,coalesce(a.ends_on,ay.ends_on),coalesce(p_until,ay.ends_on))
    into v_start,v_end from public.academic_years ay where ay.id=a.academic_year_id;

  for item in
    select fpi.*,ft.name fee_type_name from public.fee_plan_items fpi
    join public.fee_types ft on ft.id=fpi.fee_type_id
    where fpi.fee_plan_id=a.fee_plan_id
    order by coalesce(fpi.sequence_no,0),fpi.created_at
  loop
    if item.billing_frequency='ONCE' then
      occurrence:=coalesce(item.starts_on,v_start);
      if occurrence between v_start and v_end then
        due_date:=case when item.due_day is null then occurrence
          else make_date(extract(year from occurrence)::int,extract(month from occurrence)::int,
            least(item.due_day,extract(day from (date_trunc('month',occurrence)+interval '1 month - 1 day'))::int)) end;
        if not exists(select 1 from public.charges c where c.student_id=a.student_id and c.academic_year_id=a.academic_year_id and c.fee_type_id=item.fee_type_id and c.due_on=due_date and c.status<>'CANCELLED') then
          insert into public.charges(school_id,student_id,academic_year_id,fee_type_id,amount,due_on,description)
          values(a.school_id,a.student_id,a.academic_year_id,item.fee_type_id,item.amount,due_date,item.fee_type_name);
          created_count:=created_count+1;
        end if;
      end if;
    elsif item.billing_frequency='ACADEMIC_YEAR' then
      due_date:=coalesce(item.starts_on,v_start);
      if item.due_day is not null then
        due_date:=make_date(extract(year from due_date)::int,extract(month from due_date)::int,
          least(item.due_day,extract(day from (date_trunc('month',due_date)+interval '1 month - 1 day'))::int));
      end if;
      if due_date between v_start and v_end and not exists(select 1 from public.charges c where c.student_id=a.student_id and c.academic_year_id=a.academic_year_id and c.fee_type_id=item.fee_type_id and c.due_on=due_date and c.status<>'CANCELLED') then
        insert into public.charges(school_id,student_id,academic_year_id,fee_type_id,amount,due_on,description)
        values(a.school_id,a.student_id,a.academic_year_id,item.fee_type_id,item.amount,due_date,item.fee_type_name);
        created_count:=created_count+1;
      end if;
    else
      occurrence:=date_trunc('month',v_start)::date;
      while occurrence <= v_end loop
        if item.billing_frequency='MONTHLY' or
           (item.billing_frequency='QUARTERLY' and mod((extract(year from age(occurrence,v_start))*12+extract(month from age(occurrence,v_start)))::int,3)=0) then
          due_date:=make_date(extract(year from occurrence)::int,extract(month from occurrence)::int,
            least(coalesce(item.due_day,extract(day from occurrence)::int),
              extract(day from (date_trunc('month',occurrence)+interval '1 month - 1 day'))::int));
          if due_date between v_start and v_end and not exists(select 1 from public.charges c where c.student_id=a.student_id and c.academic_year_id=a.academic_year_id and c.fee_type_id=item.fee_type_id and c.due_on=due_date and c.status<>'CANCELLED') then
            insert into public.charges(school_id,student_id,academic_year_id,fee_type_id,amount,due_on,description)
            values(a.school_id,a.student_id,a.academic_year_id,item.fee_type_id,item.amount,due_date,item.fee_type_name || ' — ' || to_char(occurrence,'TMMonth YYYY'));
            created_count:=created_count+1;
          end if;
        end if;
        occurrence:=(occurrence+interval '1 month')::date;
      end loop;
    end if;
  end loop;

  result:=jsonb_build_object('assignment_id',a.id,'created_charges',created_count);
  perform private.complete_command('generate_student_fee_plan_charges',a.school_id,p_idempotency_key,result);
  return result;
end $$;

revoke all on function public.assign_student_fee_plan(uuid,uuid,uuid,date,date,text,text) from public;
grant execute on function public.assign_student_fee_plan(uuid,uuid,uuid,date,date,text,text) to authenticated;
revoke all on function public.generate_student_fee_plan_charges(uuid,date,text,text) from public;
grant execute on function public.generate_student_fee_plan_charges(uuid,date,text,text) to authenticated;
