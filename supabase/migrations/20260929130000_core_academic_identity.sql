-- SIGE 0001 — Core academic and identity schema
-- This migration is intentionally infrastructure-only: no seed data and no
-- remote project assumptions beyond Supabase's auth.users contract.

create extension if not exists btree_gist;

create schema if not exists private;

create type public.academic_year_status as enum ('DRAFT','OPEN','CLOSED');
create type public.person_status as enum ('ACTIVE','INACTIVE','ARCHIVED');
create type public.student_status as enum ('ACTIVE','INACTIVE','ARCHIVED');
create type public.employment_status as enum ('PENDING','ACTIVE','SUSPENDED','TERMINATED');
create type public.account_status as enum ('PENDING','ACTIVE','SUSPENDED','REVOKED');
create type public.enrollment_status as enum (
  'PENDING','ACTIVE','TRANSFERRED_IN','TRANSFERRED_OUT',
  'WITHDRAWN','CANCELLED','COMPLETED'
);
create type public.enrollment_entry_type as enum (
  'INITIAL','LATE','TRANSFER_IN','RETURNING','OTHER'
);
create type public.placement_status as enum ('ACTIVE','ENDED','CANCELLED');
create type public.shift_code as enum ('MORNING','AFTERNOON','EVENING','FULL_DAY');
create type public.class_group_status as enum ('PLANNED','OPEN','ACTIVE','CLOSED','CANCELLED');
create type public.course_offering_status as enum ('PLANNED','OPEN','ACTIVE','CLOSED','CANCELLED');
create type public.assignment_position as enum ('PRIMARY','ASSISTANT','SUBSTITUTE');
create type public.assessment_period_kind as enum ('TRIMESTER_1','TRIMESTER_2','TRIMESTER_3','EXAM','RECOVERY');
create type public.assessment_type as enum ('ACS','AT','EXAM','OTHER');
create type public.assessment_status as enum ('DRAFT','OPEN','CLOSED','PUBLISHED','CANCELLED');
create type public.assessment_result_status as enum (
  'MISSING','ENTERED','ABSENT','EXCUSED','INVALIDATED','PUBLISHED'
);
create type public.academic_result_type as enum (
  'TRIMESTER','FREQUENCY','EXAM','FINAL','RECOVERY'
);
create type public.academic_result_status as enum (
  'CALCULATED','REVIEWED','PUBLISHED','SUPERSEDED','CANCELLED'
);

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  legal_name text,
  country_code text not null default 'MZ',
  timezone text not null default 'Africa/Maputo',
  status public.person_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schools_code_ck check (length(trim(code)) between 2 and 50),
  constraint schools_name_ck check (length(trim(name)) >= 2)
);

create table public.education_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  sort_order integer not null,
  active boolean not null default true,
  constraint education_levels_sort_ck check (sort_order > 0),
  constraint education_levels_name_ck check (length(trim(name)) >= 2)
);

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  label text not null,
  starts_on date not null,
  ends_on date not null,
  status public.academic_year_status not null default 'DRAFT',
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, code),
  constraint academic_year_dates_ck check (ends_on > starts_on),
  constraint academic_year_close_ck check (
    (status = 'CLOSED' and closed_at is not null and closed_by is not null)
    or
    (status <> 'CLOSED' and closed_at is null and closed_by is null)
  )
);

create unique index academic_year_one_open_per_school
  on public.academic_years (school_id)
  where status = 'OPEN';

create table public.people (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  preferred_name text,
  date_of_birth date,
  sex text,
  nationality text,
  bi_number text,
  phone text,
  email text,
  current_address text,
  status public.person_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint people_name_ck check (length(trim(full_name)) >= 2)
);

create unique index people_bi_number_uq
  on public.people (lower(trim(bi_number)))
  where bi_number is not null and length(trim(bi_number)) > 0;

create index people_name_idx on public.people (lower(full_name));
create index people_dob_idx on public.people (date_of_birth);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  school_number text not null,
  status public.student_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, school_number),
  constraint students_school_number_ck check (length(trim(school_number)) >= 3)
);

create table public.student_identifiers (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  identifier_type text not null,
  identifier_value text not null,
  issuing_country text,
  valid_from date,
  valid_until date,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (student_id, identifier_type, identifier_value),
  constraint student_identifiers_dates_ck check (
    valid_until is null or valid_from is null or valid_until >= valid_from
  )
);

create unique index student_primary_identifier_uq
  on public.student_identifiers (student_id, identifier_type)
  where is_primary;

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id) on delete restrict,
  occupation text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.student_guardians (
  student_id uuid not null references public.students(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id) on delete restrict,
  relationship_type text not null,
  is_primary boolean not null default false,
  legal_responsibility boolean not null default false,
  receives_communications boolean not null default true,
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_id, relationship_type),
  constraint student_guardian_dates_ck check (
    ends_on is null or starts_on is null or ends_on >= starts_on
  )
);

create table public.teachers (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  employee_number text,
  status public.person_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_number)
);

create table public.staff_members (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  employee_number text,
  department text,
  status public.person_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_number)
);

create table public.employments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  teacher_id uuid references public.teachers(id) on delete restrict,
  staff_member_id uuid references public.staff_members(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  status public.employment_status not null default 'PENDING',
  job_title text not null,
  created_at timestamptz not null default now(),
  constraint employments_subject_ck check (
    (teacher_id is not null and staff_member_id is null)
    or
    (teacher_id is null and staff_member_id is not null)
  ),
  constraint employments_dates_ck check (
    ends_on is null or ends_on >= starts_on
  )
);

create index employments_teacher_idx on public.employments (teacher_id, starts_on);
create index employments_staff_idx on public.employments (staff_member_id, starts_on);

create table public.app_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete restrict,
  status public.account_status not null default 'PENDING',
  activated_at timestamptz,
  suspended_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_accounts_state_ck check (
    (status = 'ACTIVE' and activated_at is not null and revoked_at is null)
    or
    (status = 'PENDING' and activated_at is null and revoked_at is null)
    or
    (status = 'SUSPENDED' and suspended_at is not null and revoked_at is null)
    or
    (status = 'REVOKED' and revoked_at is not null)
  )
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  system_role boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table public.account_roles (
  account_id uuid not null references public.app_accounts(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  primary key (account_id, role_id),
  constraint account_roles_dates_ck check (
    ends_at is null or ends_at > starts_at
  )
);

create table public.grade_levels (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null references public.education_levels(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  unique (education_level_id, code),
  unique (education_level_id, ordinal),
  constraint grade_levels_ordinal_ck check (ordinal > 0)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  short_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code),
  constraint subjects_name_ck check (length(trim(name)) >= 2)
);

create table public.curriculum_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  weekly_periods numeric(5,2),
  mandatory boolean not null default true,
  active boolean not null default true,
  unique (academic_year_id, grade_level_id, subject_id),
  constraint curriculum_subjects_periods_ck check (
    weekly_periods is null or weekly_periods > 0
  )
);

create table public.class_groups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  code text not null,
  name text not null,
  shift public.shift_code,
  room text,
  capacity integer,
  status public.class_group_status not null default 'PLANNED',
  opened_on date,
  closed_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (academic_year_id, code),
  constraint class_groups_capacity_ck check (capacity is null or capacity > 0),
  constraint class_groups_dates_ck check (
    closed_on is null or opened_on is null or closed_on >= opened_on
  )
);

create table public.student_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  status public.enrollment_status not null default 'PENDING',
  entry_type public.enrollment_entry_type not null default 'INITIAL',
  enrolled_on date not null,
  exited_on date,
  exit_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, academic_year_id),
  constraint enrollments_dates_ck check (
    exited_on is null or exited_on >= enrolled_on
  ),
  constraint enrollments_exit_ck check (
    (status in ('TRANSFERRED_OUT','WITHDRAWN','CANCELLED','COMPLETED')
      and exited_on is not null)
    or
    (status in ('PENDING','ACTIVE','TRANSFERRED_IN') and exited_on is null)
  )
);

create table public.class_placements (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.student_enrollments(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  status public.placement_status not null default 'ACTIVE',
  reason text,
  created_at timestamptz not null default now(),
  constraint class_placements_dates_ck check (
    ends_on is null or ends_on >= starts_on
  )
);

alter table public.class_placements
  add constraint class_placements_student_no_overlap
  exclude using gist (
    (enrollment_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status <> 'CANCELLED');

create table public.course_offerings (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  curriculum_subject_id uuid references public.curriculum_subjects(id) on delete restrict,
  code text not null,
  status public.course_offering_status not null default 'PLANNED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (academic_year_id, code),
  unique (class_group_id, subject_id)
);

create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  position public.assignment_position not null default 'PRIMARY',
  starts_on date not null,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint teacher_assignments_dates_ck check (
    ends_on is null or ends_on >= starts_on
  )
);

alter table public.teacher_assignments
  add constraint teacher_assignments_no_overlap
  exclude using gist (
    (teacher_id) with =,
    (course_offering_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (active);

create table public.student_course_participations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  unique (student_id, course_offering_id),
  constraint student_course_participation_dates_ck check (
    ends_on is null or ends_on >= starts_on
  )
);

create table public.assessment_periods (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  kind public.assessment_period_kind not null,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  sequence_no integer,
  active boolean not null default true,
  unique (academic_year_id, kind),
  constraint assessment_period_dates_ck check (ends_on >= starts_on),
  constraint assessment_period_sequence_ck check (
    sequence_no is null or sequence_no > 0
  )
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  assessment_period_id uuid not null references public.assessment_periods(id) on delete restrict,
  type public.assessment_type not null,
  title text not null,
  assessment_date date,
  max_score numeric(8,4) not null default 20,
  weight numeric(8,4),
  status public.assessment_status not null default 'DRAFT',
  published_at timestamptz,
  published_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assessments_max_score_ck check (max_score > 0),
  constraint assessments_weight_ck check (weight is null or weight >= 0)
);

create table public.assessment_results (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  raw_score numeric(8,4),
  normalized_score numeric(8,4),
  status public.assessment_result_status not null default 'MISSING',
  comment text,
  entered_by uuid references auth.users(id) on delete set null,
  entered_at timestamptz,
  published_at timestamptz,
  published_by uuid references auth.users(id) on delete set null,
  corrected_from uuid references public.assessment_results(id) on delete set null,
  correction_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_id, student_id),
  constraint assessment_results_score_ck check (
    raw_score is null or raw_score >= 0
  ),
  constraint assessment_results_normalized_ck check (
    normalized_score is null or normalized_score between 0 and 20
  )
);

create table public.grade_rule_versions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  version integer not null,
  effective_from date not null,
  effective_until date,
  definition jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code, version),
  constraint grade_rule_version_ck check (version > 0),
  constraint grade_rule_dates_ck check (
    effective_until is null or effective_until >= effective_from
  )
);

create table public.academic_results (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  assessment_period_id uuid references public.assessment_periods(id) on delete restrict,
  result_type public.academic_result_type not null,
  value numeric(8,4),
  displayed_value numeric(8,4),
  rule_version_id uuid references public.grade_rule_versions(id) on delete restrict,
  status public.academic_result_status not null default 'CALCULATED',
  source_snapshot jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  published_at timestamptz,
  published_by uuid references auth.users(id) on delete set null,
  supersedes_result_id uuid references public.academic_results(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (student_id, course_offering_id, assessment_period_id, result_type),
  constraint academic_results_value_ck check (
    value is null or value between 0 and 20
  ),
  constraint academic_results_displayed_ck check (
    displayed_value is null or displayed_value between 0 and 20
  )
);

-- Indexes for the access paths used by school operations.
create index students_school_status_idx on public.students (school_id, status);
create index enrollments_year_status_idx on public.student_enrollments (academic_year_id, status);
create index enrollments_student_idx on public.student_enrollments (student_id);
create index placements_class_idx on public.class_placements (class_group_id, starts_on);
create index offerings_class_idx on public.course_offerings (class_group_id, status);
create index offerings_subject_idx on public.course_offerings (subject_id, academic_year_id);
create index assignments_offering_idx on public.teacher_assignments (course_offering_id, active);
create index participations_student_idx on public.student_course_participations (student_id, status);
create index assessments_offering_period_idx on public.assessments (course_offering_id, assessment_period_id);
create index assessment_results_student_idx on public.assessment_results (student_id);
create index academic_results_student_idx on public.academic_results (student_id, course_offering_id);

-- RLS is enabled now; policies are introduced in the security migration.
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in (
        'schools','education_levels','academic_years','people','students',
        'student_identifiers','guardians','student_guardians','teachers',
        'staff_members','employments','app_accounts','roles','permissions',
        'role_permissions','account_roles','grade_levels','subjects',
        'curriculum_subjects','class_groups','student_enrollments',
        'class_placements','course_offerings','teacher_assignments',
        'student_course_participations','assessment_periods','assessments',
        'assessment_results','grade_rule_versions','academic_results'
      )
  loop
    execute format('alter table public.%I enable row level security', r.relname);
  end loop;
end $$;
