-- SIGE 0017 — cross-aggregate scope integrity regression
begin;
select plan(15);

select ok(exists(select 1 from pg_proc where proname='validate_academic_scope' and pronamespace='private'::regnamespace),'cross-aggregate scope validator exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_curriculum_scope'),'curriculum scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_class_group_scope'),'class group scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_course_offering_scope'),'course offering scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_enrollment_scope'),'enrollment scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_class_placement_scope'),'class placement scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_course_participation_scope'),'course participation scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_teacher_assignment_scope'),'teacher assignment scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_assessment_scope'),'assessment scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_assessment_result_scope'),'assessment result scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_schedule_entry_scope'),'schedule entry scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_class_session_scope'),'class session scope trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_attendance_scope'),'attendance scope trigger exists');
select ok(position('COURSE_PARTICIPATION_CLASS_CONTEXT_MISMATCH' in pg_get_functiondef('private.validate_academic_scope()'::regprocedure)) > 0,'course participation validates class context');
select * from finish();
rollback;