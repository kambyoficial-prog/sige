-- SIGE 0022 — closed academic year write barrier regression
begin;
select plan(14);

select ok(exists(select 1 from pg_proc where proname='guard_closed_academic_year_mutation' and pronamespace='private'::regnamespace),'closed-year guard exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_student_enrollments'),'enrollment write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_class_groups'),'class group write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_course_offerings'),'course offering write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_assessment_periods'),'assessment period write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_class_placements'),'class placement write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_student_course_participations'),'course participation write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_teacher_assignments'),'teacher assignment write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_schedule_entries'),'schedule write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_class_sessions'),'session write barrier exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_closed_year_attendance_records'),'attendance write barrier exists');
select ok(position('ACADEMIC_YEAR_CLOSED' in pg_get_functiondef('private.guard_closed_academic_year_mutation()'::regprocedure)) > 0,'guard rejects closed years');
select ok(position('student_course_participations' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close ends course participations');
select ok(position('course_offerings' in pg_get_functiondef('public.close_academic_year(uuid,date,text,text,text)'::regprocedure)) > 0,'year close closes offerings');
select * from finish();
rollback;