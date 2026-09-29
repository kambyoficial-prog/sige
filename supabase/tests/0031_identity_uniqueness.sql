-- SIGE 0046 regression — identity uniqueness
begin;
select plan(2);

select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='people_national_id_uq'),'national identity has a physical uniqueness constraint');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='guardians_school_identity_number_uq'),'guardian identity is unique within school');

select * from finish();
rollback;
