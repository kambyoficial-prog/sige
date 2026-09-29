-- SIGE 0032 — financial configuration and temporal integrity
--
-- Financial configuration may be reusable across years, but whenever it is
-- year-bound it must remain inside one school/year context. Operational
-- receivables and services cannot be edited against a closed academic year.

create or replace function private.validate_financial_configuration_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  plan_school uuid;
  plan_year uuid;
  plan_year_school uuid;
  fee_school uuid;
  student_school uuid;
  service_year_school uuid;
  service_year_start date;
  service_year_end date;
  charge_school uuid;
  charge_year uuid;
  charge_year_status public.academic_year_status;
  payment_school uuid;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_table_name = 'fee_plans' then
    if new.academic_year_id is not null then
      select ay.school_id into plan_year_school
      from public.academic_years ay
      where ay.id = new.academic_year_id;

      if plan_year_school is null or plan_year_school <> new.school_id then
        raise exception 'FEE_PLAN_YEAR_SCHOOL_MISMATCH';
      end if;
    end if;
    return new;
  end if;

  if tg_table_name = 'fee_plan_items' then
    select fp.school_id, fp.academic_year_id
      into plan_school, plan_year
    from public.fee_plans fp
    where fp.id = new.fee_plan_id;

    select ft.school_id into fee_school
    from public.fee_types ft
    where ft.id = new.fee_type_id;

    if plan_school is null or fee_school is null or plan_school <> fee_school then
      raise exception 'FEE_PLAN_ITEM_SCHOOL_MISMATCH';
    end if;

    if plan_year is not null then
      select ay.school_id into plan_year_school
      from public.academic_years ay
      where ay.id = plan_year;

      if plan_year_school <> plan_school then
        raise exception 'FEE_PLAN_ITEM_YEAR_SCHOOL_MISMATCH';
      end if;
    end if;

    return new;
  end if;

  if tg_table_name = 'student_services' then
    select s.school_id into student_school
    from public.students s
    where s.id = new.student_id;

    select ay.school_id, ay.starts_on, ay.ends_on
      into service_year_school, service_year_start, service_year_end
    from public.academic_years ay
    where ay.id = new.academic_year_id;

    if student_school is null
       or service_year_school is null
       or student_school <> service_year_school then
      raise exception 'STUDENT_SERVICE_YEAR_CONTEXT_MISMATCH';
    end if;

    if new.starts_on is not null
       and (new.starts_on < service_year_start or new.starts_on > service_year_end) then
      raise exception 'STUDENT_SERVICE_START_OUTSIDE_ACADEMIC_YEAR';
    end if;

    if new.ends_on is not null
       and (new.ends_on < service_year_start or new.ends_on > service_year_end) then
      raise exception 'STUDENT_SERVICE_END_OUTSIDE_ACADEMIC_YEAR';
    end if;

    if exists (
      select 1
      from public.academic_years ay
      where ay.id = new.academic_year_id
        and ay.status = 'CLOSED'
    ) then
      raise exception 'ACADEMIC_YEAR_CLOSED';
    end if;

    return new;
  end if;

  if tg_table_name = 'charges' then
    select ay.school_id, ay.status
      into charge_school, charge_year_status
    from public.academic_years ay
    where ay.id = new.academic_year_id;

    if charge_school is null or charge_school <> new.school_id then
      raise exception 'CHARGE_YEAR_SCHOOL_MISMATCH';
    end if;

    select ay.id, ay.starts_on, ay.ends_on
      into charge_year, service_year_start, service_year_end
    from public.academic_years ay
    where ay.id = new.academic_year_id;

    if new.due_on < service_year_start or new.due_on > service_year_end then
      raise exception 'CHARGE_DUE_DATE_OUTSIDE_ACADEMIC_YEAR';
    end if;

    if charge_year_status = 'CLOSED' then
      raise exception 'ACADEMIC_YEAR_CLOSED';
    end if;

    return new;
  end if;

  if tg_table_name = 'charge_adjustments' then
    select c.school_id, c.academic_year_id
      into charge_school, charge_year
    from public.charges c
    where c.id = new.charge_id;

    if charge_school is null then
      raise exception 'CHARGE_NOT_FOUND';
    end if;

    if exists (
      select 1
      from public.academic_years ay
      where ay.id = charge_year
        and ay.status = 'CLOSED'
    ) then
      raise exception 'ACADEMIC_YEAR_CLOSED';
    end if;

    return new;
  end if;

  if tg_table_name = 'payment_reversals' then
    select p.school_id into payment_school
    from public.payments p
    where p.id = new.payment_id;

    if payment_school is null then
      raise exception 'PAYMENT_NOT_FOUND';
    end if;

    return new;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_financial_configuration_scope() from public;

drop trigger if exists trg_validate_fee_plan_scope on public.fee_plans;
create trigger trg_validate_fee_plan_scope
before insert or update on public.fee_plans
for each row execute function private.validate_financial_configuration_scope();

drop trigger if exists trg_validate_fee_plan_item_scope on public.fee_plan_items;
create trigger trg_validate_fee_plan_item_scope
before insert or update on public.fee_plan_items
for each row execute function private.validate_financial_configuration_scope();

drop trigger if exists trg_validate_student_service_temporal_scope on public.student_services;
create trigger trg_validate_student_service_temporal_scope
before insert or update on public.student_services
for each row execute function private.validate_financial_configuration_scope();

drop trigger if exists trg_validate_charge_temporal_scope on public.charges;
create trigger trg_validate_charge_temporal_scope
before insert or update on public.charges
for each row execute function private.validate_financial_configuration_scope();

drop trigger if exists trg_validate_charge_adjustment_temporal_scope on public.charge_adjustments;
create trigger trg_validate_charge_adjustment_temporal_scope
before insert or update on public.charge_adjustments
for each row execute function private.validate_financial_configuration_scope();

drop trigger if exists trg_validate_payment_reversal_scope on public.payment_reversals;
create trigger trg_validate_payment_reversal_scope
before insert or update on public.payment_reversals
for each row execute function private.validate_financial_configuration_scope();

create index if not exists fee_plans_school_year_idx
  on public.fee_plans (school_id, academic_year_id, active);

create index if not exists student_services_student_year_idx
  on public.student_services (student_id, academic_year_id, active);

create index if not exists charge_adjustments_charge_idx
  on public.charge_adjustments (charge_id, created_at desc);
