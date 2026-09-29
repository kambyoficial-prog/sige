-- SIGE 0000 — Executable database foundation
-- This migration is the dependency root for all later SIGE migrations.
-- It intentionally contains domain structure only; operational hardening is
-- layered in subsequent migrations.

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create schema if not exists private;

create type public.academic_year_status as enum ('DRAFT','OPEN','CLOSED');
create type public.enrollment_entry_type as enum ('INITIAL','TRANSFER_IN','REENTRY');
create type public.enrollment_status as enum (
  'PENDING','ACTIVE','TRANSFERRED_IN','TRANSFERRED_OUT',
  'WITHDRAWN','CANCELLED','COMPLETED'
);
create type public.class_group_status as enum ('DRAFT','OPEN','ACTIVE','CLOSED','CANCELLED');
create type public.course_offering_status as enum ('DRAFT','OPEN','ACTIVE','CLOSED','CANCELLED');
create type public.assessment_type as enum ('ACS','AT','EXAM','OTHER');
create type public.assessment_status as enum ('OPEN','PUBLISHED','CLOSED','CANCELLED');
create type public.assessment_result_status as enum (
  'MISSING','ENTERED','ABSENT','EXCUSED','INVALIDATED','PUBLISHED'
);
create type public.payment_status as enum ('PENDING','CONFIRMED','REVERSED','CANCELLED');
create type public.payment_method as enum (
  'CASH','BANK_TRANSFER','MOBILE_MONEY','CARD','OTHER'
);
create type public.charge_status as enum (
  'OPEN','PARTIALLY_PAID','PAID','OVERDUE','CANCELLED','WAIVED'
);
create type public.charge_adjustment_type as enum (
  'DISCOUNT','WAIVER','REVERSAL','SURCHARGE','CORRECTION'
);

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  short_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schools_code_ck check (length(trim(code)) >= 2)
);

create table public.people (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  first_name text,
  last_name text,
  gender text,
  birth_date date,
  national_id text,
  phone text,
  email text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint people_name_ck check (length(trim(full_name)) >= 2)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  school_number text not null,
  status text not null default 'ACTIVE',
  admission_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, school_number),
  unique (person_id),
  constraint students_status_ck check (status in ('ACTIVE','INACTIVE','ARCHIVED'))
);

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  relationship text,
  occupation text,
  identity_number text,
  address text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, person_id)
);

create table public.student_guardians (
  student_id uuid not null references public.students(id) on delete restrict,
  guardian_id uuid not null references public.guardians(id) on delete restrict,
  relationship text,
  is_primary boolean not null default false,
  lives_with_student boolean,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_id)
);

create table public.student_identifiers (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  type text not null,
  value text not null,
  created_at timestamptz not null default now(),
  unique (student_id, type),
  unique (type, value)
);

create table public.teachers (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  employee_code text not null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_code),
  unique (person_id),
  constraint teachers_status_ck check (status in ('ACTIVE','INACTIVE','ARCHIVED'))
);

create table public.staff_members (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  employee_code text not null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_code),
  unique (person_id)
);

create table public.employments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  employee_code text,
  job_title text,
  starts_on date not null,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint employments_dates_ck check (ends_on is null or ends_on >= starts_on)
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
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
  role_id uuid not null references public.roles(id) on delete restrict,
  permission_id uuid not null references public.permissions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.app_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_roles (
  app_account_id uuid not null references public.app_accounts(id) on delete restrict,
  role_id uuid not null references public.roles(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  starts_on date,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (app_account_id, role_id, school_id)
);

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  label text not null,
  starts_on date not null,
  ends_on date not null,
  status public.academic_year_status not null default 'DRAFT',
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, label),
  constraint academic_year_dates_ck check (ends_on >= starts_on)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  short_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table public.education_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.academic_cycles (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null references public.education_levels(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (education_level_id, code),
  unique (education_level_id, ordinal)
);

create table public.grade_levels (
  id uuid primary key default gen_random_uuid(),
  academic_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (academic_cycle_id, code),
  unique (academic_cycle_id, ordinal)
);

create table public.curriculum_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  weekly_periods integer,
  mandatory boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (academic_year_id, grade_level_id, subject_id),
  constraint curriculum_weekly_periods_ck check (weekly_periods is null or weekly_periods > 0)
);

create table public.class_groups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  code text,
  name text,
  status public.class_group_status not null default 'DRAFT',
  capacity integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_groups_capacity_base_ck check (capacity is null or capacity > 0)
);

create table public.course_offerings (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  curriculum_subject_id uuid references public.curriculum_subjects(id) on delete restrict,
  status public.course_offering_status not null default 'DRAFT',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_group_id, subject_id)
);

create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint teacher_assignments_dates_ck check (ends_on is null or ends_on >= starts_on)
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
  enrollment_sequence integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_enrollments_dates_ck check (exited_on is null or exited_on >= enrolled_on),
  constraint student_enrollments_sequence_ck check (enrollment_sequence > 0),
  unique (student_id, academic_year_id, enrollment_sequence)
);

create table public.class_placements (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.student_enrollments(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  status text not null default 'ACTIVE',
  reason text,
  created_at timestamptz not null default now(),
  constraint class_placements_dates_ck check (ends_on is null or ends_on >= starts_on),
  constraint class_placements_status_ck check (status in ('ACTIVE','ENDED','CANCELLED'))
);

create table public.student_course_participations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  starts_on date not null default current_date,
  ends_on date,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  constraint student_course_participations_dates_ck check (ends_on is null or ends_on >= starts_on),
  constraint student_course_participations_status_ck check (status in ('ACTIVE','ENDED','CANCELLED')),
  unique (student_id, course_offering_id, starts_on)
);

create table public.assessment_periods (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  starts_on date,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (academic_year_id, code),
  unique (academic_year_id, ordinal),
  constraint assessment_periods_ordinal_ck check (ordinal > 0),
  constraint assessment_periods_dates_ck check (ends_on is null or starts_on is null or ends_on >= starts_on)
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
  status public.assessment_status not null default 'OPEN',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assessments_score_ck check (max_score > 0),
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
  correction_reason text,
  entered_by uuid references auth.users(id) on delete set null,
  entered_at timestamptz,
  published_at timestamptz,
  published_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_id, student_id),
  constraint assessment_results_raw_ck check (raw_score is null or raw_score >= 0),
  constraint assessment_results_normalized_ck check (normalized_score is null or (normalized_score >= 0 and normalized_score <= 20))
);

create table public.grade_rule_versions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  version text not null,
  definition jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint grade_rule_versions_definition_ck check (jsonb_typeof(definition) = 'object')
);

create table public.fee_types (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table public.fee_plans (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid references public.academic_years(id) on delete restrict,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table public.fee_plan_items (
  id uuid primary key default gen_random_uuid(),
  fee_plan_id uuid not null references public.fee_plans(id) on delete restrict,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  amount numeric(12,2) not null,
  due_day integer,
  sequence_no integer,
  created_at timestamptz not null default now(),
  constraint fee_plan_items_amount_ck check (amount >= 0),
  constraint fee_plan_items_due_day_ck check (due_day is null or due_day between 1 and 31),
  constraint fee_plan_items_sequence_ck check (sequence_no is null or sequence_no > 0)
);

create table public.transport_services (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  route text,
  stop text,
  amount numeric(12,2),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code),
  constraint transport_services_amount_ck check (amount is null or amount >= 0)
);

create table public.student_services (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  service_type text not null,
  transport_service_id uuid references public.transport_services(id) on delete restrict,
  active boolean not null default true,
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  constraint student_services_dates_ck check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create table public.charges (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  fee_type_id uuid references public.fee_types(id) on delete restrict,
  amount numeric(12,2) not null,
  due_on date not null,
  status public.charge_status not null default 'OPEN',
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint charges_amount_ck check (amount >= 0)
);

create table public.charge_adjustments (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.charges(id) on delete restrict,
  type public.charge_adjustment_type not null,
  amount numeric(12,2) not null,
  reason text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint charge_adjustments_amount_ck check (amount > 0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  amount numeric(12,2) not null,
  method public.payment_method not null,
  status public.payment_status not null default 'PENDING',
  paid_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  external_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_amount_ck check (amount > 0)
);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  charge_id uuid not null references public.charges(id) on delete restrict,
  amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  constraint payment_allocations_amount_ck check (amount > 0),
  unique (payment_id, charge_id)
);

create table public.payment_reversals (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  amount numeric(12,2) not null,
  reason text not null,
  reversed_at timestamptz not null default now(),
  reversed_by uuid references auth.users(id) on delete set null,
  constraint payment_reversals_amount_ck check (amount > 0)
);

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  receipt_number text not null,
  issued_at timestamptz not null default now(),
  issued_by uuid references auth.users(id) on delete set null,
  unique (school_id, receipt_number),
  unique (payment_id)
);

create index students_school_idx on public.students (school_id, status);
create index enrollments_student_year_idx on public.student_enrollments (student_id, academic_year_id);
create index placements_enrollment_idx on public.class_placements (enrollment_id, status);
create index offerings_class_year_idx on public.course_offerings (class_group_id, academic_year_id);
create index teacher_assignments_teacher_idx on public.teacher_assignments (teacher_id, active);
create index assessments_offering_period_idx on public.assessments (course_offering_id, assessment_period_id);
create index assessment_results_student_idx on public.assessment_results (student_id, assessment_id);
create index charges_student_idx on public.charges (student_id, school_id);
create index payments_student_idx on public.payments (student_id, school_id);

-- Authorization helpers. They are intentionally DB-owned and do not read
-- user-editable JWT metadata.
create or replace function private.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select aa.person_id
  from public.app_accounts aa
  where aa.auth_user_id = (select auth.uid())
    and aa.active;
$$;

create or replace function private.has_permission(
  p_permission_code text,
  p_school_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_accounts aa
    join public.account_roles ar
      on ar.app_account_id = aa.id
     and ar.active
     and (ar.starts_on is null or ar.starts_on <= current_date)
     and (ar.ends_on is null or ar.ends_on >= current_date)
    join public.role_permissions rp on rp.role_id = ar.role_id
    join public.permissions p on p.id = rp.permission_id
    where aa.auth_user_id = (select auth.uid())
      and aa.active
      and ar.school_id = p_school_id
      and p.code = p_permission_code
  );
$$;

revoke all on function private.current_person_id() from public;
revoke all on function private.has_permission(text, uuid) from public;

-- Base authorization catalog.
insert into public.roles (code, name, description) values
  ('DIRECTION','Direção','Gestão geral da escola.'),
  ('SECRETARIAT','Secretaria','Gestão administrativa e escolar.'),
  ('PEDAGOGICAL_DIRECTION','Direção Pedagógica','Gestão pedagógica.'),
  ('TEACHER','Professor','Operação pedagógica do docente.'),
  ('STUDENT','Aluno','Acesso do aluno.'),
  ('GUARDIAN','Encarregado','Acesso do encarregado.')
on conflict (code) do nothing;

insert into public.permissions (code, name, description) values
  ('administration.manage','Gerir administração','Administração geral.'),
  ('enrollment.read','Consultar matrículas','Consultar matrícula e inscrição.'),
  ('enrollment.manage','Gerir matrículas','Criar e gerir matrículas.'),
  ('assessment.read','Consultar avaliação','Consultar avaliações e resultados.'),
  ('assessment.manage','Gerir avaliação','Gerir avaliações e resultados.'),
  ('assessment.own.enter','Lançar avaliação própria','Professor lança resultados das próprias ofertas.'),
  ('finance.read','Consultar finanças','Consultar obrigações e pagamentos.'),
  ('finance.manage','Gerir finanças','Gerir obrigações e pagamentos.'),
  ('operations.read','Consultar operação escolar','Consultar horários e operação.'),
  ('operations.manage','Gerir operação escolar','Gerir horários e operação.'),
  ('attendance.own.manage','Gerir próprio livro de ponto','Gerir sessões próprias.')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where
  (r.code = 'DIRECTION')
  or (r.code = 'SECRETARIAT' and p.code in (
    'administration.manage','enrollment.read','enrollment.manage',
    'assessment.read','finance.read','finance.manage','operations.read','operations.manage'
  ))
  or (r.code = 'PEDAGOGICAL_DIRECTION' and p.code in (
    'enrollment.read','assessment.read','assessment.manage','operations.read'
  ))
  or (r.code = 'TEACHER' and p.code in (
    'assessment.read','assessment.own.enter','operations.read','attendance.own.manage'
  ))
  or (r.code = 'STUDENT' and p.code in ('assessment.read'))
  or (r.code = 'GUARDIAN' and p.code in ('assessment.read'))
on conflict do nothing;

-- Read boundary for the foundational tables. Write boundaries are tightened
-- by later command-specific migrations.
alter table public.schools enable row level security;
alter table public.people enable row level security;
alter table public.students enable row level security;
alter table public.guardians enable row level security;
alter table public.student_guardians enable row level security;
alter table public.student_identifiers enable row level security;
alter table public.teachers enable row level security;
alter table public.staff_members enable row level security;
alter table public.employments enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.app_accounts enable row level security;
alter table public.account_roles enable row level security;
alter table public.academic_years enable row level security;
alter table public.subjects enable row level security;
alter table public.curriculum_subjects enable row level security;
alter table public.class_groups enable row level security;
alter table public.course_offerings enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.student_enrollments enable row level security;
alter table public.class_placements enable row level security;
alter table public.student_course_participations enable row level security;
alter table public.assessment_periods enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_results enable row level security;
alter table public.education_levels enable row level security;
alter table public.academic_cycles enable row level security;
alter table public.grade_levels enable row level security;
alter table public.grade_rule_versions enable row level security;
alter table public.fee_types enable row level security;
alter table public.fee_plans enable row level security;
alter table public.fee_plan_items enable row level security;
alter table public.transport_services enable row level security;
alter table public.student_services enable row level security;
alter table public.charges enable row level security;
alter table public.charge_adjustments enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.payment_reversals enable row level security;
alter table public.receipts enable row level security;

create policy foundation_education_levels_read on public.education_levels for select to authenticated using (true);
create policy foundation_academic_cycles_read on public.academic_cycles for select to authenticated using (true);
create policy foundation_grade_levels_read on public.grade_levels for select to authenticated using (true);

create policy people_read on public.people for select to authenticated using (true);
create policy roles_read on public.roles for select to authenticated using (true);
create policy permissions_read on public.permissions for select to authenticated using (true);
create policy role_permissions_read on public.role_permissions for select to authenticated using (true);
create policy grade_rules_read on public.grade_rule_versions for select to authenticated using (active);
create policy schools_read on public.schools for select to authenticated
  using (private.has_permission('administration.manage', id));

create policy students_read on public.students for select to authenticated
  using (private.has_permission('enrollment.read', school_id) or private.has_permission('enrollment.manage', school_id));

create policy teachers_read on public.teachers for select to authenticated
  using (private.has_permission('operations.read', school_id) or private.has_permission('assessment.read', school_id));

create policy staff_members_read on public.staff_members for select to authenticated
  using (private.has_permission('administration.manage', school_id));

create policy academic_years_read on public.academic_years for select to authenticated
  using (private.has_permission('enrollment.read', school_id) or private.has_permission('operations.read', school_id) or private.has_permission('assessment.read', school_id));

create policy subjects_read on public.subjects for select to authenticated
  using (school_id is null or private.has_permission('assessment.read', school_id) or private.has_permission('operations.read', school_id));

create policy curriculum_subjects_read on public.curriculum_subjects for select to authenticated
  using (private.has_permission('assessment.read', school_id) or private.has_permission('operations.read', school_id));

create policy class_groups_read on public.class_groups for select to authenticated
  using (private.has_permission('operations.read', school_id) or private.has_permission('enrollment.read', school_id));

create policy course_offerings_read on public.course_offerings for select to authenticated
  using (private.has_permission('assessment.read', school_id) or private.has_permission('operations.read', school_id));

create policy teacher_assignments_read on public.teacher_assignments for select to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = teacher_assignments.course_offering_id
        and (
          private.has_permission('assessment.read', co.school_id)
          or private.has_permission('operations.read', co.school_id)
        )
    )
  );

create policy enrollments_read on public.student_enrollments for select to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_enrollments.student_id
        and private.has_permission('enrollment.read', s.school_id)
    )
  );

create policy class_placements_read on public.class_placements for select to authenticated
  using (
    exists (
      select 1 from public.class_groups cg
      where cg.id = class_placements.class_group_id
        and (private.has_permission('enrollment.read', cg.school_id) or private.has_permission('operations.read', cg.school_id))
    )
  );

create policy student_course_participations_read on public.student_course_participations for select to authenticated
  using (
    exists (
      select 1
      from public.course_offerings co
      where co.id = student_course_participations.course_offering_id
        and private.has_permission('assessment.read', co.school_id)
    )
  );

create policy assessment_periods_read on public.assessment_periods for select to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = assessment_periods.academic_year_id
        and private.has_permission('assessment.read', ay.school_id)
    )
  );

create policy assessments_read on public.assessments for select to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = assessments.course_offering_id
        and private.has_permission('assessment.read', co.school_id)
    )
  );

create policy assessment_results_read on public.assessment_results for select to authenticated
  using (
    exists (
      select 1
      from public.assessments a
      join public.course_offerings co on co.id = a.course_offering_id
      where a.id = assessment_results.assessment_id
        and private.has_permission('assessment.read', co.school_id)
    )
  );

create policy financial_read on public.charges for select to authenticated
  using (private.has_permission('finance.read', school_id) or private.has_permission('finance.manage', school_id));

create policy payments_read on public.payments for select to authenticated
  using (private.has_permission('finance.read', school_id) or private.has_permission('finance.manage', school_id));

grant select on all tables in schema public to authenticated;

-- Explicitly no anonymous access.
revoke all on all tables in schema public from anon;

