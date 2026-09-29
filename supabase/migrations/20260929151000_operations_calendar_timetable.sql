-- SIGE 0008 — Calendar, timetable and class-session domain

create type public.schedule_entry_status as enum ('DRAFT','ACTIVE','ENDED','CANCELLED');
create type public.attendance_status as enum ('PRESENT','ABSENT','EXCUSED','LATE');

create table public.school_calendar_days (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  school_date date not null,
  instructional boolean not null default true,
  label text,
  created_at timestamptz not null default now(),
  unique (academic_year_id, school_date)
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  capacity integer,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code),
  constraint rooms_capacity_ck check (capacity is null or capacity > 0)
);

create table public.schedule_periods (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  starts_at time not null,
  ends_at time not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, code),
  unique (school_id, ordinal),
  constraint schedule_periods_order_ck check (ends_at > starts_at)
);

create table public.schedule_entries (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  teacher_assignment_id uuid not null references public.teacher_assignments(id) on delete restrict,
  room_id uuid references public.rooms(id) on delete restrict,
  period_id uuid not null references public.schedule_periods(id) on delete restrict,
  day_of_week smallint not null,
  valid_from date not null,
  valid_until date,
  status public.schedule_entry_status not null default 'DRAFT',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedule_entries_day_ck check (day_of_week between 1 and 7),
  constraint schedule_entries_dates_ck check (valid_until is null or valid_until >= valid_from)
);

alter table public.schedule_entries
  add constraint schedule_class_no_overlap
  exclude using gist (
    (class_group_id) with =,
    (day_of_week) with =,
    (period_id) with =,
    daterange(valid_from, coalesce(valid_until + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status in ('DRAFT','ACTIVE'));

alter table public.schedule_entries
  add constraint schedule_teacher_no_overlap
  exclude using gist (
    (teacher_assignment_id) with =,
    (day_of_week) with =,
    (period_id) with =,
    daterange(valid_from, coalesce(valid_until + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status in ('DRAFT','ACTIVE'));

alter table public.schedule_entries
  add constraint schedule_room_no_overlap
  exclude using gist (
    (room_id) with =,
    (day_of_week) with =,
    (period_id) with =,
    daterange(valid_from, coalesce(valid_until + 1, '9999-12-31'::date), '[)') with &&
  )
  where (room_id is not null and status in ('DRAFT','ACTIVE'));

create table public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  schedule_entry_id uuid not null references public.schedule_entries(id) on delete restrict,
  session_date date not null,
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  topic text,
  notes text,
  status text not null default 'PLANNED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (schedule_entry_id, session_date)
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references public.class_sessions(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  status public.attendance_status not null,
  minutes_late integer,
  reason text,
  recorded_by uuid references auth.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_session_id, student_id),
  constraint attendance_minutes_ck check (minutes_late is null or minutes_late >= 0)
);

create index schedule_entries_class_idx on public.schedule_entries (class_group_id, day_of_week, period_id);
create index schedule_entries_teacher_idx on public.schedule_entries (teacher_assignment_id, day_of_week, period_id);
create index class_sessions_date_idx on public.class_sessions (session_date, course_offering_id);
create index attendance_records_student_idx on public.attendance_records (student_id, class_session_id);

insert into public.permissions (code, name, description)
values
  ('operations.read', 'Consultar operação escolar', 'Consultar calendário, horários e livro de ponto.'),
  ('operations.manage', 'Gerir operação escolar', 'Gerir calendário, horários, salas e sessões.'),
  ('attendance.own.manage', 'Gerir próprio livro de ponto', 'Professor regista informação de sessões das próprias ofertas.')
on conflict (code) do update
set name = excluded.name, description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on
  (r.code in ('DIRECTION','SECRETARIAT') and p.code in ('operations.read','operations.manage'))
  or (r.code = 'PEDAGOGICAL_DIRECTION' and p.code = 'operations.read')
  or (r.code = 'TEACHER' and p.code in ('operations.read','attendance.own.manage'))
on conflict do nothing;

alter table public.school_calendar_days enable row level security;
alter table public.rooms enable row level security;
alter table public.schedule_periods enable row level security;
alter table public.schedule_entries enable row level security;
alter table public.class_sessions enable row level security;
alter table public.attendance_records enable row level security;
