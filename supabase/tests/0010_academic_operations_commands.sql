-- SIGE 0023 — Academic operations command contract tests
begin;

select plan(18);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'class_groups_year_grade_section_pathway_uidx'
  ) or exists (
    select 1 from pg_indexes
    where indexname = 'class_groups_year_grade_section_pathway_uidx'
  ),
  'class section uniqueness includes curricular pathway'
);

select ok(
  exists (
    select 1 from pg_indexes
    where indexname = 'academic_pathways_cycle_code_scope_uidx'
  ),
  'pathway scope uniqueness is deterministic for global and school-scoped pathways'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'teacher_assignments_offering_teacher_no_overlap'
  ),
  'same teacher cannot be assigned twice to the same offering during overlapping dates'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'create_class_group'
  ),
  'create class command exists'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'update_class_group'
  ),
  'update class command exists'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'close_class_group'
  ),
  'close class command exists'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'generate_class_offerings'
  ),
  'curriculum-to-offering command exists'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'assign_teacher_to_offering'
  ),
  'teacher assignment command exists'
);

select ok(
  exists (
    select 1 from pg_proc
    where proname = 'transfer_student_class'
  ),
  'class transfer command exists'
);

select ok(
  exists (
    select 1 from pg_trigger
    where tgname = 'trg_validate_course_offering_context'
  ),
  'course offering context is validated by database trigger'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'class_groups'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'class groups cannot be mutated through generic authenticated CRUD'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'course_offerings'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'course offerings cannot be mutated through generic authenticated CRUD'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'teacher_assignments'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'teacher assignments cannot be mutated through generic authenticated CRUD'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'class_placements'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'class placements cannot be mutated through generic authenticated CRUD'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'student_course_participations'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'course participation cannot be mutated through generic authenticated CRUD'
);

select ok(
  exists (
    select 1
    from information_schema.routines
    where routine_schema = 'public'
      and routine_name = 'transfer_student_class'
  ),
  'transfer is exposed as a controlled command rather than a table mutation'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'generate_class_offerings'
      and pg_get_functiondef(p.oid) like '%curriculum_subjects%'
  ),
  'offering generation derives from curriculum instead of duplicating subject lists'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'transfer_student_class'
      and pg_get_functiondef(p.oid) like '%student_course_participations%'
  ),
  'class transfer preserves instructional participation history'
);

select * from finish();
rollback;
