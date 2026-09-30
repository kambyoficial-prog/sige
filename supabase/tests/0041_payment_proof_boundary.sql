-- 0041 — payment proof evidence and confirmation/receipt invariants
begin;

do $$
begin
  if not exists (
    select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace
    where n.nspname='public' and t.typname='payment_proof_status'
  ) then raise exception 'payment_proof_status type missing'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='payment_proofs' and c.relrowsecurity
  ) then raise exception 'payment_proofs RLS missing'; end if;

  if has_function_privilege('anon','public.create_payment_proof_upload(uuid,text,text,bigint,text,text)','execute')
     or has_function_privilege('anon','public.finalize_payment_proof(uuid,text,text)','execute')
     or has_function_privilege('anon','public.verify_payment_proof(uuid,public.payment_proof_status,text,text,text)','execute') then
    raise exception 'payment proof mutation must not be executable by anon';
  end if;

  if not has_function_privilege('authenticated','public.create_payment_proof_upload(uuid,text,text,bigint,text,text)','execute')
     or not has_function_privilege('authenticated','public.finalize_payment_proof(uuid,text,text)','execute')
     or not has_function_privilege('authenticated','public.verify_payment_proof(uuid,public.payment_proof_status,text,text,text)','execute') then
    raise exception 'payment proof command grants missing';
  end if;

  if exists (
    select 1
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('create_payment_proof_upload','finalize_payment_proof','verify_payment_proof')
      and (not p.prosecdef or p.proconfig is null
        or not exists(select 1 from unnest(p.proconfig) c where c='search_path=""'))
  ) then raise exception 'payment proof SECURITY DEFINER boundary invalid'; end if;

  if not exists (
    select 1 from pg_policies where schemaname='storage' and tablename='objects'
      and policyname='payment_proofs_storage_insert'
  ) then raise exception 'payment proof storage INSERT policy missing'; end if;

  if not exists (
    select 1 from pg_policies where schemaname='storage' and tablename='objects'
      and policyname='payment_proofs_storage_select'
  ) then raise exception 'payment proof storage SELECT policy missing'; end if;
end $$;

rollback;
