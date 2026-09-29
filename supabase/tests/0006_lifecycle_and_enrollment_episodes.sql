begin;

select plan(10);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='student_enrollments'
      and column_name='enrollment_sequence'
  ),
  'enrollment episodes have a sequence'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname='student_enrollments_no_temporal_overlap'
  ),
  'enrollment episodes cannot overlap'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname='student_enrollments_sequence_ck'
  ),
  'enrollment sequence is positive'
);

select ok(
  has_function('public','open_academic_year',array['uuid','text','text']),
  'open academic year command exists'
);

select ok(
  has_function('public','close_academic_year',array['uuid','date','text','text','text']),
  'close academic year command exists'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='academic_years'
      and grantee='authenticated' and privilege_type='UPDATE'
  ),
  'authenticated cannot mutate academic year state directly'
);

select ok(
  exists (
    select 1 from information_schema.routine_privileges
    where routine_schema='public' and routine_name='close_academic_year'
      and grantee='authenticated' and privilege_type='EXECUTE'
  ),
  'authenticated may invoke close command subject to permission'
);

select ok(
  exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='student_enrollments_episode_uq'
  ),
  'enrollment episode identity is unique'
);

select ok(
  exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='student_enrollments_student_year_idx'
  ),
  'enrollment history has a student/year access path'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname='class_placements_student_no_overlap'
  ),
  'class placements remain temporally exclusive per enrollment'
);

select * from finish();
rollback;
