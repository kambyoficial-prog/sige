-- SIGE 0020 — enrollment lifecycle regression
begin;
select plan(5);

select ok(position('PLACEMENT_DATE_OUTSIDE_ACADEMIC_YEAR' in pg_get_functiondef('public.place_student_in_class(uuid,uuid,date,date,text,text,text)'::regprocedure)) > 0,'class placement dates are bounded by the enrollment academic year');
select ok(position('SCHOOL_CONTEXT_MISMATCH' in pg_get_functiondef('public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,text,text)'::regprocedure)) > 0,'enrollment enforces school context');
select ok(position('ACTIVE_ENROLLMENT_ALREADY_EXISTS' in pg_get_functiondef('public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,text,text)'::regprocedure)) > 0,'overlapping active enrollment is rejected');
select ok(position('CLASS_CONTEXT_MISMATCH' in pg_get_functiondef('public.place_student_in_class(uuid,uuid,date,date,text,text,text)'::regprocedure)) > 0,'placement enforces class context');
select ok(position('set search_path = '''' in pg_get_functiondef('public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,text,text)'::regprocedure)) > 0,'enrollment command has pinned search path');

select * from finish();
rollback;