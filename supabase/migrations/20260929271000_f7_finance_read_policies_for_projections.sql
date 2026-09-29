drop policy if exists finance_read_payment_allocations on public.payment_allocations;
create policy finance_read_payment_allocations on public.payment_allocations for select to authenticated using(exists(select 1 from public.payments p where p.id=payment_id and (private.has_permission('finance.read',p.school_id) or private.has_permission('finance.manage',p.school_id))));
drop policy if exists finance_read_payment_reversals on public.payment_reversals;
create policy finance_read_payment_reversals on public.payment_reversals for select to authenticated using(exists(select 1 from public.payments p where p.id=payment_id and (private.has_permission('finance.read',p.school_id) or private.has_permission('finance.manage',p.school_id))));
drop policy if exists finance_read_receipts on public.receipts;
create policy finance_read_receipts on public.receipts for select to authenticated using(private.has_permission('finance.read',school_id) or private.has_permission('finance.manage',school_id));