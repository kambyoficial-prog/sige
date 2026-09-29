begin;

select plan(14);

select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='students'),'students table exists');
select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='student_enrollments'),'student_enrollments exists');
select ok(exists(select 1 from pg_constraint where conname='class_placements_student_no_overlap'),'student placement overlap constraint exists');
select ok(exists(select 1 from pg_constraint where conname='teacher_assignments_no_overlap'),'teacher assignment overlap constraint exists');
select ok(exists(select 1 from pg_constraint where conname='student_enrollments_student_id_academic_year_id_key'),'one annual enrollment is constrained');
select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='students' and c.relrowsecurity),'students RLS enabled');
select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='charges' and c.relrowsecurity),'charges RLS enabled');
select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='audit_events' and c.relrowsecurity),'audit RLS enabled');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='has_permission'),'authorization function exists');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='current_person_id'),'identity resolver exists');
select ok(exists(select 1 from pg_views where schemaname='public' and viewname='student_financial_balances'),'financial balance view exists');
select ok(exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='audit_events'),'audit event store exists');
select ok(exists(select 1 from pg_constraint where conname='payment_allocations_amount_ck'),'payment allocation constraint exists');
select ok(exists(select 1 from pg_constraint where conname='charges_amount_ck'),'charge amount constraint exists');

select * from finish();
rollback;
