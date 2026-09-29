begin;

select plan(24);

select ok(
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'education_levels'
  ),
  'education levels exist'
);

select ok(
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'academic_cycles'
  ),
  'academic cycles exist'
);

select ok(
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'academic_pathways'
  ),
  'academic pathways exist'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'class_groups'
      and column_name = 'pathway_id'
  ),
  'class groups support curricular pathways'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'class_groups'
      and column_name = 'section_code'
  ),
  'class groups distinguish section code from pathway'
);

select ok(
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'class_group_leadership'
  ),
  'class director is a temporal relationship'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'class_group_leadership_no_overlap'
  ),
  'a class cannot have overlapping active directors'
);

select ok(
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'teacher_workload_targets'
  ),
  'teacher workload targets exist'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'class_group_overview'
  ),
  'class overview projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'class_group_students'
  ),
  'class students projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'class_group_teachers'
  ),
  'class teachers projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'class_timetable'
  ),
  'class timetable projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'teacher_timetable'
  ),
  'teacher timetable projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'student_timetable'
  ),
  'student timetable projection exists'
);

select ok(
  exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'timetable_slot_usage'
  ),
  'timetable planning projection exists'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'schedule_teacher_no_overlap'
  ),
  'teacher schedule overlap remains a hard database constraint'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'schedule_class_no_overlap'
  ),
  'class schedule overlap remains a hard database constraint'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'schedule_room_no_overlap'
  ),
  'room schedule overlap remains a hard database constraint'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'assign_class_group_director'
  ),
  'class director assignment is a controlled command'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'class_group_leadership'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'class director history cannot be directly mutated by authenticated clients'
);

select ok(
  exists (
    select 1 from public.education_levels
    where code = 'ES' and name = 'Ensino Secundário'
  ),
  'secondary education is seeded'
);

select ok(
  (
    select count(*)
    from public.grade_levels gl
    join public.academic_cycles ac on ac.id = gl.academic_cycle_id
    join public.education_levels el on el.id = ac.education_level_id
    where el.code = 'ES'
  ) = 6,
  'secondary education has six grades across two cycles'
);

select * from finish();
rollback;
