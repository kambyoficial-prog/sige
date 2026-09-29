-- SIGE 0019 — privileged function security regression
begin;
select plan(4);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where p.prosecdef
      and n.nspname in ('public','private')
      and pg_get_functiondef(p.oid) ilike '%set search_path = public%'
  ),
  'no public/private SECURITY DEFINER function uses a public search_path'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where p.prosecdef
      and n.nspname in ('public','private')
      and pg_get_functiondef(p.oid) not ilike '%set search_path%'
  ),
  'all public/private SECURITY DEFINER functions pin search_path'
);

select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prosecdef and n.nspname='public' and p.proname='record_payment'),'financial command remains SECURITY DEFINER');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prosecdef and n.nspname='public' and p.proname='save_assessment_result'),'assessment command remains SECURITY DEFINER');

select * from finish();
rollback;