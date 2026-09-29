-- F7 finance command boundary regression
begin;
do $$
declare n integer;
begin
  select count(*) into n from information_schema.routines where routine_schema='public'
    and routine_name in ('create_fee_type','create_fee_plan','add_fee_plan_item','create_transport_service','assign_student_transport','create_charge','adjust_charge');
  if n <> 7 then raise exception 'F7 command count mismatch: %',n; end if;

  if exists(select 1 from information_schema.role_table_grants
    where grantee='authenticated' and table_schema='public'
      and table_name in ('fee_types','fee_plans','fee_plan_items','transport_services','student_services','charges','charge_adjustments')
      and privilege_type in ('INSERT','UPDATE','DELETE')) then
    raise exception 'F7 direct financial mutation privilege still exposed';
  end if;

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='payment_allocations' and policyname='finance_read_payment_allocations') then
    raise exception 'payment allocation read boundary missing';
  end if;
  if not exists(select 1 from pg_views where schemaname='public' and viewname='finance_balance_directory') then
    raise exception 'finance balance directory missing';
  end if;
end $$;
rollback;