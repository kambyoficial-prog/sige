begin;

select plan(18);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='app_accounts'
      and column_name='person_id'
      and is_nullable='NO'
  ),
  'active application accounts are bound to a domain person'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_enrollment_context'),
  'enrollment context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_class_placement_context'),
  'class placement context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_course_offering_context'),
  'course offering context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_teacher_assignment_context'),
  'teacher assignment context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_student_course_participation_context'),
  'student course participation context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_assessment_context'),
  'assessment period/year context trigger exists'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_validate_assessment_result_context'),
  'assessment result participation trigger exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='assessment_result_history'
      and c.relrowsecurity
  ),
  'assessment result history is protected by RLS'
);

select ok(
  exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='assessment_result_history'
      and grantee='authenticated'
      and privilege_type='SELECT'
  ),
  'authenticated can read assessment result history through policy/grant boundary'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='assessment_result_history'
      and grantee='authenticated'
      and privilege_type='INSERT'
  ),
  'authenticated cannot directly insert result history'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='assessment_result_history'
      and grantee='authenticated'
      and privilege_type='UPDATE'
  ),
  'authenticated cannot directly update result history'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='assessment_result_history'
      and grantee='authenticated'
      and privilege_type='DELETE'
  ),
  'authenticated cannot directly delete result history'
);

select ok(
  exists (select 1 from pg_trigger where tgname='trg_capture_published_result_revision'),
  'published result revision trigger exists'
);

select ok(
  exists (select 1 from pg_constraint where conname='schedule_class_no_overlap'),
  'class timetable overlap constraint exists'
);

select ok(
  exists (select 1 from pg_constraint where conname='schedule_teacher_no_overlap'),
  'teacher timetable overlap constraint exists'
);

select ok(
  exists (select 1 from pg_constraint where conname='schedule_room_no_overlap'),
  'room timetable overlap constraint exists'
);

select * from finish();
rollback;
