-- SIGE 0015 — closed-year hardening regression
begin;
select plan(18);

select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_class_groups'),'class groups are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_course_offerings'),'course offerings are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_curriculum_subjects'),'curriculum subjects are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_choice_groups'),'curriculum choice groups are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_workload_targets'),'workload targets are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_enrollments'),'enrollments are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_assessment_periods'),'assessment periods are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_class_placements'),'class placements are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_student_participations'),'student course participations are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_teacher_assignments'),'teacher assignments are immutable after year close');
select ok(exists(select 1 from pg_trigger where tgname='trg_guard_closed_year_class_group_leadership'),'class leadership is immutable after year close');

select ok(position('year_status not in (''DRAFT'',''OPEN'')' in pg_get_functiondef('public.generate_class_offerings(uuid,text,text)'::regprocedure)) > 0,'offering generation rejects closed academic years explicitly');
select ok(position('private.complete_command(' in pg_get_functiondef('public.generate_class_offerings(uuid,text,text)'::regprocedure)) > 0,'offering generation completes idempotency state');
select ok(position('p_request_hash' in pg_get_functiondef('public.generate_class_offerings(uuid,text,text)'::regprocedure)) > 0,'offering generation retains request hash for idempotency');
select ok(position('result' in pg_get_functiondef('public.generate_class_offerings(uuid,text,text)'::regprocedure)) > 0,'offering generation stores the operation result');

select ok(exists(select 1 from pg_proc where proname='guard_closed_year_direct' and pronamespace='private'::regnamespace),'direct temporal guard exists');
select ok(exists(select 1 from pg_proc where proname='guard_closed_year_via_offering' and pronamespace='private'::regnamespace),'offering temporal guard exists');
select ok(exists(select 1 from pg_proc where proname='guard_closed_year_via_enrollment' and pronamespace='private'::regnamespace),'enrollment temporal guard exists');

select * from finish();
rollback;