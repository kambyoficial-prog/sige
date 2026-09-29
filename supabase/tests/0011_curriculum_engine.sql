-- SIGE 0024 — Curriculum engine contract tests
begin;

select plan(14);

select ok(
  exists (select 1 from pg_type where typname = 'curriculum_selection_mode'),
  'curriculum selection mode exists'
);

select ok(
  exists (select 1 from pg_class where relname = 'curriculum_areas'),
  'curriculum areas exist'
);

select ok(
  exists (select 1 from pg_class where relname = 'curriculum_choice_groups'),
  'curriculum choice groups exist'
);

select ok(
  exists (
    select 1 from pg_indexes
    where indexname = 'curriculum_subjects_context_subject_uidx'
  ),
  'curriculum subject uniqueness includes pathway context'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='curriculum_subjects'
      and column_name='curriculum_area_id'
  ),
  'curriculum subject can belong to a curricular area'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='curriculum_subjects'
      and column_name='choice_group_id'
  ),
  'curriculum subject can belong to a choice group'
);

select ok(
  exists (
    select 1 from pg_trigger
    where tgname='trg_validate_curriculum_subject_context'
  ),
  'curriculum subject context is validated by database'
);

select ok(
  exists (select 1 from pg_proc where proname='configure_curriculum_subject'),
  'curriculum configuration command exists'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='curriculum_subjects'
      and grantee='authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'curriculum subjects cannot be changed through generic CRUD'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name='curriculum_choice_groups'
      and grantee='authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'choice groups cannot be changed through generic CRUD'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname='curriculum_subjects_selection_consistency_ck'
  ),
  'selection mode and mandatory/choice state are consistent'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conname='curriculum_choice_max_ck'
  ),
  'choice group bounds are consistent'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='configure_curriculum_subject'
      and pg_get_functiondef(p.oid) like '%begin_command%'
  ),
  'curriculum configuration is idempotent/command based'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='configure_curriculum_subject'
      and pg_get_functiondef(p.oid) like '%audit_events%'
  ),
  'curriculum configuration is audited'
);

select * from finish();
rollback;
