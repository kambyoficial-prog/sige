-- SIGE 0040 — timetable and assessment integration regression
begin;
select plan(8);

select ok(exists(select 1 from pg_trigger where tgname='trg_validate_schedule_teacher_conflict'),'teacher-level timetable conflict trigger exists');
select ok(position('SCHEDULE_TEACHER_CONFLICT' in pg_get_functiondef('private.validate_schedule_teacher_conflict()'::regprocedure)) > 0,'teacher conflict is explicitly rejected');
select ok(position('teacher_id = teacher_id' in pg_get_functiondef('private.validate_schedule_teacher_conflict()'::regprocedure)) > 0,'conflict is evaluated by teacher identity');
select ok(position('TEACHER_ASSIGNMENT_CONTEXT_MISMATCH' in pg_get_functiondef('private.validate_schedule_teacher_conflict()'::regprocedure)) > 0,'schedule assignment context is validated');
select ok(position('scp.status in (''ACTIVE'',''ENDED'')' in pg_get_functiondef('public.calculate_trimester_result(uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'trimester calculation supports historical participation overlapping the period');
select ok(position('MZ-ES-2022-06-30' in pg_get_functiondef('public.calculate_trimester_result(uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'trimester calculation is rule-versioned');
select ok(position('status = ''PUBLISHED''' in pg_get_functiondef('public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'frequency calculation uses published trimester results');
select ok(position('status = ''PUBLISHED''' in pg_get_functiondef('public.calculate_final_result(uuid,uuid,uuid,uuid,text,text)'::regprocedure)) > 0,'final calculation uses published source results');

select * from finish();
rollback;