-- SIGE 0022 — Academic structure, pathways, class leadership and timetable projections
--
-- This migration formalizes the academic hierarchy without hard-coding a
-- particular school's section/pathway vocabulary:
-- education level -> cycle -> grade -> pathway -> class group -> course offering
-- -> teacher assignment / student participation.
--
-- Pathways are intentionally configurable. Official curriculum revisions and
-- school availability can change the concrete A/B/C (or other) options.

create table if not exists public.education_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint education_levels_code_ck check (length(trim(code)) >= 2),
  constraint education_levels_ordinal_ck check (ordinal > 0)
);

create table if not exists public.academic_cycles (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null references public.education_levels(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (education_level_id, code),
  unique (education_level_id, ordinal),
  constraint academic_cycles_ordinal_ck check (ordinal > 0)
);

create table if not exists public.grade_levels (
  id uuid primary key default gen_random_uuid(),
  academic_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (academic_cycle_id, code),
  unique (academic_cycle_id, ordinal),
  constraint grade_levels_ordinal_ck check (ordinal > 0)
);

create table if not exists public.academic_pathways (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete restrict,
  academic_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  kind text not null default 'AREA',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, academic_cycle_id, code),
  constraint academic_pathways_kind_ck check (kind in ('COMMON','AREA','OPTION','SPECIALIZATION')),
  constraint academic_pathways_code_ck check (length(trim(code)) >= 1)
);

alter table public.class_groups
  add column if not exists pathway_id uuid references public.academic_pathways(id) on delete restrict,
  add column if not exists section_code text,
  add column if not exists shift text,
  add column if not exists name text,
  add column if not exists capacity integer;

alter table public.class_groups
  add constraint class_groups_capacity_ck
  check (capacity is null or capacity > 0);

alter table public.class_groups
  add constraint class_groups_section_code_ck
  check (section_code is null or length(trim(section_code)) >= 1);

alter table public.class_groups
  add constraint class_groups_shift_ck
  check (shift is null or shift in ('MORNING','AFTERNOON','EVENING','FULL_DAY'));

create unique index if not exists class_groups_year_grade_section_uidx
  on public.class_groups (academic_year_id, grade_level_id, lower(section_code))
  where section_code is not null;

create index if not exists class_groups_pathway_idx
  on public.class_groups (pathway_id);

create table if not exists public.class_group_leadership (
  id uuid primary key default gen_random_uuid(),
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  active boolean not null default true,
  reason text,
  created_at timestamptz not null default now(),
  constraint class_group_leadership_dates_ck
    check (ends_on is null or ends_on >= starts_on)
);

create index if not exists class_group_leadership_group_idx
  on public.class_group_leadership (class_group_id, starts_on desc);

alter table public.class_group_leadership
  add constraint class_group_leadership_no_overlap
  exclude using gist (
    (class_group_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (active);

create table if not exists public.teacher_workload_targets (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  target_periods_per_week integer,
  max_periods_per_day integer,
  preferred_shift text,
  notes text,
  created_at timestamptz not null default now(),
  unique (teacher_id, academic_year_id),
  constraint teacher_workload_target_week_ck
    check (target_periods_per_week is null or target_periods_per_week >= 0),
  constraint teacher_workload_target_day_ck
    check (max_periods_per_day is null or max_periods_per_day >= 0),
  constraint teacher_workload_target_shift_ck
    check (preferred_shift is null or preferred_shift in ('MORNING','AFTERNOON','EVENING','FULL_DAY'))
);

-- Curriculum subjects may be common to the cycle or specific to a pathway.
alter table public.curriculum_subjects
  add column if not exists pathway_id uuid references public.academic_pathways(id) on delete restrict;

create index if not exists curriculum_subjects_pathway_idx
  on public.curriculum_subjects (pathway_id);

-- A course offering remains the annual instructional contract for one class and
-- subject. A teacher assignment is the temporal staffing relation. This allows
-- one teacher to teach many classes and a class to have many teachers.
create index if not exists teacher_assignments_teacher_year_idx
  on public.teacher_assignments (teacher_id, starts_on, ends_on);

create index if not exists teacher_assignments_offering_idx
  on public.teacher_assignments (course_offering_id, active, starts_on);

create index if not exists student_course_participations_student_idx
  on public.student_course_participations (student_id, course_offering_id, status);

alter table public.class_placements
  add constraint class_placements_enrollment_no_overlap
  exclude using gist (
    (enrollment_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status = 'ACTIVE');

alter table public.student_course_participations
  add constraint student_course_participations_no_overlap
  exclude using gist (
    (student_id) with =,
    (course_offering_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (status = 'ACTIVE');

create index if not exists class_placements_group_idx
  on public.class_placements (class_group_id, status, starts_on);

create or replace function private.validate_class_group_academic_structure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $sige$
declare
  grade_cycle uuid;
  pathway_cycle uuid;
  pathway_school uuid;
begin
  select gl.academic_cycle_id
    into grade_cycle
  from public.grade_levels gl
  where gl.id = new.grade_level_id;

  if grade_cycle is null then
    raise exception 'GRADE_LEVEL_NOT_FOUND';
  end if;

  if new.pathway_id is not null then
    select ap.academic_cycle_id, ap.school_id
      into pathway_cycle, pathway_school
    from public.academic_pathways ap
    where ap.id = new.pathway_id;

    if pathway_cycle is null then
      raise exception 'PATHWAY_NOT_FOUND';
    end if;

    if pathway_cycle <> grade_cycle then
      raise exception 'CLASS_GROUP_PATHWAY_CYCLE_MISMATCH';
    end if;

    if pathway_school is not null and pathway_school <> new.school_id then
      raise exception 'CLASS_GROUP_PATHWAY_SCHOOL_MISMATCH';
    end if;
  end if;

  return new;
end;
$sige$;

drop trigger if exists trg_validate_class_group_academic_structure on public.class_groups;
create trigger trg_validate_class_group_academic_structure
before insert or update on public.class_groups
for each row execute function private.validate_class_group_academic_structure();

create or replace function public.assign_class_group_director(
  p_class_group_id uuid,
  p_teacher_id uuid,
  p_starts_on date,
  p_ends_on date default null,
  p_reason text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $sige$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  year_id uuid;
  year_start date;
  year_end date;
  leadership_id uuid;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select cg.school_id, cg.academic_year_id, ay.starts_on, ay.ends_on
    into school_id, year_id, year_start, year_end
  from public.class_groups cg
  join public.academic_years ay on ay.id = cg.academic_year_id
  where cg.id = p_class_group_id
  for update;

  if school_id is null then raise exception 'CLASS_GROUP_NOT_FOUND'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_starts_on < year_start
     or p_starts_on > year_end
     or (p_ends_on is not null and (p_ends_on < p_starts_on or p_ends_on > year_end)) then
    raise exception 'DIRECTOR_DATES_OUTSIDE_ACADEMIC_YEAR';
  end if;

  if not exists (
    select 1
    from public.teachers t
    where t.id = p_teacher_id
      and t.school_id = school_id
  ) then
    raise exception 'TEACHER_NOT_FOUND_IN_SCHOOL';
  end if;

  if not exists (
    select 1
    from public.course_offerings co
    join public.teacher_assignments ta on ta.course_offering_id = co.id
    where co.class_group_id = p_class_group_id
      and ta.teacher_id = p_teacher_id
      and ta.active
      and ta.starts_on <= coalesce(p_ends_on, year_end)
      and (ta.ends_on is null or ta.ends_on >= p_starts_on)
  ) then
    raise exception 'DIRECTOR_MUST_TEACH_CLASS';
  end if;

  command_state := private.begin_command(
    'assign_class_group_director',
    school_id,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.class_group_leadership
     set active = false,
         ends_on = case
           when starts_on < p_starts_on then p_starts_on - 1
           else ends_on
         end
   where class_group_id = p_class_group_id
     and active
     and starts_on <= p_starts_on
     and (ends_on is null or ends_on >= p_starts_on);

  insert into public.class_group_leadership (
    class_group_id,
    teacher_id,
    starts_on,
    ends_on,
    active,
    reason
  )
  values (
    p_class_group_id,
    p_teacher_id,
    p_starts_on,
    p_ends_on,
    true,
    nullif(trim(p_reason), '')
  )
  returning id into leadership_id;

  insert into public.audit_events (
    school_id,
    actor_auth_user_id,
    action,
    entity_type,
    entity_id,
    reason,
    after_data
  )
  values (
    school_id,
    actor,
    'ASSIGN_CLASS_GROUP_DIRECTOR',
    'class_group_leadership',
    leadership_id,
    nullif(trim(p_reason), ''),
    jsonb_build_object(
      'class_group_id', p_class_group_id,
      'teacher_id', p_teacher_id,
      'starts_on', p_starts_on,
      'ends_on', p_ends_on
    )
  );

  result := jsonb_build_object(
    'class_group_leadership_id', leadership_id,
    'class_group_id', p_class_group_id,
    'teacher_id', p_teacher_id,
    'starts_on', p_starts_on,
    'ends_on', p_ends_on
  );

  perform private.complete_command(
    'assign_class_group_director',
    school_id,
    p_idempotency_key,
    result
  );

  return result;
end;
$sige$;

revoke all on function private.validate_class_group_academic_structure() from public;
revoke all on function public.assign_class_group_director(uuid,uuid,date,date,text,text,text) from public;
grant execute on function public.assign_class_group_director(uuid,uuid,date,date,text,text,text) to authenticated;

revoke insert, update, delete on public.class_group_leadership from authenticated;
revoke insert, update, delete on public.teacher_workload_targets from authenticated;
grant select, insert, update on public.teacher_workload_targets to authenticated;

create policy class_group_leadership_manage
on public.class_group_leadership
for select to authenticated
using (
  exists (
    select 1 from public.class_groups cg
    where cg.id = class_group_leadership.class_group_id
      and private.has_permission('operations.manage', cg.school_id)
  )
);

create policy teacher_workload_targets_manage
on public.teacher_workload_targets
for all to authenticated
using (
  exists (
    select 1 from public.academic_years ay
    where ay.id = teacher_workload_targets.academic_year_id
      and private.has_permission('operations.manage', ay.school_id)
  )
)
with check (
  exists (
    select 1 from public.academic_years ay
    where ay.id = teacher_workload_targets.academic_year_id
      and private.has_permission('operations.manage', ay.school_id)
  )
);

-- Controlled projections for the UI and reports. They are not sources of truth.

create or replace view public.class_group_overview
with (security_invoker = true)
as
select
  cg.id,
  cg.school_id,
  cg.academic_year_id,
  cg.grade_level_id,
  gl.name as grade_name,
  gl.code as grade_code,
  ac.id as cycle_id,
  ac.name as cycle_name,
  el.id as education_level_id,
  el.name as education_level_name,
  cg.pathway_id,
  ap.code as pathway_code,
  ap.name as pathway_name,
  cg.section_code,
  cg.name as class_name,
  cg.shift,
  cg.capacity,
  count(distinct cp.id) filter (where cp.status = 'ACTIVE') as active_student_count,
  (array_agg(t.id order by cgl.starts_on desc, cgl.id desc) filter (
    where cgl.active
      and cgl.starts_on <= current_date
      and (cgl.ends_on is null or cgl.ends_on >= current_date)
  ))[1] as director_teacher_id,
  max(p.full_name) filter (
    where cgl.active
      and cgl.starts_on <= current_date
      and (cgl.ends_on is null or cgl.ends_on >= current_date)
  ) as director_teacher_name
from public.class_groups cg
join public.grade_levels gl on gl.id = cg.grade_level_id
join public.academic_cycles ac on ac.id = gl.academic_cycle_id
join public.education_levels el on el.id = ac.education_level_id
left join public.academic_pathways ap on ap.id = cg.pathway_id
left join public.class_placements cp on cp.class_group_id = cg.id
left join public.class_group_leadership cgl on cgl.class_group_id = cg.id
left join public.teachers t on t.id = cgl.teacher_id
left join public.people p on p.id = t.person_id
group by
  cg.id, cg.school_id, cg.academic_year_id, cg.grade_level_id,
  gl.name, gl.code, ac.id, ac.name, el.id, el.name,
  cg.pathway_id, ap.code, ap.name, cg.section_code, cg.name,
  cg.shift, cg.capacity;

create or replace view public.class_group_students
with (security_invoker = true)
as
select
  cp.class_group_id,
  cp.id as class_placement_id,
  cp.starts_on,
  cp.ends_on,
  s.id as student_id,
  s.school_id,
  s.school_number,
  s.person_id,
  p.full_name as student_name,
  p.gender,
  e.id as enrollment_id,
  e.academic_year_id,
  e.grade_level_id
from public.class_placements cp
join public.student_enrollments e on e.id = cp.enrollment_id
join public.students s on s.id = e.student_id
join public.people p on p.id = s.person_id
where cp.status = 'ACTIVE';

create or replace view public.class_group_teachers
with (security_invoker = true)
as
select
  co.class_group_id,
  co.id as course_offering_id,
  co.academic_year_id,
  co.subject_id,
  sub.name as subject_name,
  ta.id as teacher_assignment_id,
  ta.teacher_id,
  p.full_name as teacher_name,
  ta.starts_on,
  ta.ends_on,
  ta.active
from public.course_offerings co
join public.subjects sub on sub.id = co.subject_id
join public.teacher_assignments ta on ta.course_offering_id = co.id
join public.teachers t on t.id = ta.teacher_id
join public.people p on p.id = t.person_id
where ta.active;

create or replace view public.teacher_workload_summary
with (security_invoker = true)
as
select
  se.academic_year_id,
  se.school_id,
  se.teacher_id,
  p.full_name as teacher_name,
  count(*) filter (where se.status in ('DRAFT','ACTIVE')) as scheduled_periods_per_week,
  count(distinct se.class_group_id) filter (where se.status in ('DRAFT','ACTIVE')) as class_count,
  count(distinct se.course_offering_id) filter (where se.status in ('DRAFT','ACTIVE')) as subject_offering_count
from public.schedule_entries se
join public.teachers t on t.id = se.teacher_id
join public.people p on p.id = t.person_id
group by se.academic_year_id, se.school_id, se.teacher_id, p.full_name;

create or replace view public.class_timetable
with (security_invoker = true)
as
select
  se.id,
  se.school_id,
  se.academic_year_id,
  se.class_group_id,
  cg.section_code,
  cg.name as class_name,
  cg.grade_level_id,
  se.day_of_week,
  sp.ordinal as period_ordinal,
  sp.code as period_code,
  sp.name as period_name,
  sp.starts_at,
  sp.ends_at,
  se.course_offering_id,
  sub.id as subject_id,
  sub.code as subject_code,
  sub.name as subject_name,
  se.teacher_id,
  tp.full_name as teacher_name,
  se.room_id,
  r.code as room_code,
  r.name as room_name,
  se.valid_from,
  se.valid_until,
  se.status
from public.schedule_entries se
join public.class_groups cg on cg.id = se.class_group_id
join public.schedule_periods sp on sp.id = se.period_id
join public.course_offerings co on co.id = se.course_offering_id
join public.subjects sub on sub.id = co.subject_id
join public.teachers t on t.id = se.teacher_id
join public.people tp on tp.id = t.person_id
left join public.rooms r on r.id = se.room_id;

create or replace view public.teacher_timetable
with (security_invoker = true)
as
select
  se.id,
  se.school_id,
  se.academic_year_id,
  se.teacher_id,
  tp.full_name as teacher_name,
  se.day_of_week,
  sp.ordinal as period_ordinal,
  sp.code as period_code,
  sp.name as period_name,
  sp.starts_at,
  sp.ends_at,
  se.class_group_id,
  cg.section_code,
  cg.name as class_name,
  co.id as course_offering_id,
  sub.code as subject_code,
  sub.name as subject_name,
  se.room_id,
  r.code as room_code,
  r.name as room_name,
  se.valid_from,
  se.valid_until,
  se.status
from public.schedule_entries se
join public.teachers t on t.id = se.teacher_id
join public.people tp on tp.id = t.person_id
join public.schedule_periods sp on sp.id = se.period_id
join public.class_groups cg on cg.id = se.class_group_id
join public.course_offerings co on co.id = se.course_offering_id
join public.subjects sub on sub.id = co.subject_id
left join public.rooms r on r.id = se.room_id;

create or replace view public.student_timetable
with (security_invoker = true)
as
select
  cp.enrollment_id,
  e.student_id,
  se.id as schedule_entry_id,
  se.day_of_week,
  sp.ordinal as period_ordinal,
  sp.code as period_code,
  sp.name as period_name,
  sp.starts_at,
  sp.ends_at,
  se.class_group_id,
  co.id as course_offering_id,
  sub.code as subject_code,
  sub.name as subject_name,
  se.teacher_id,
  tp.full_name as teacher_name,
  se.room_id,
  r.code as room_code,
  r.name as room_name,
  se.valid_from,
  se.valid_until,
  se.status
from public.class_placements cp
join public.student_enrollments e on e.id = cp.enrollment_id
join public.student_course_participations scp
  on scp.student_id = e.student_id
join public.schedule_entries se
  on se.course_offering_id = scp.course_offering_id
 and se.class_group_id = cp.class_group_id
join public.schedule_periods sp on sp.id = se.period_id
join public.course_offerings co on co.id = se.course_offering_id
join public.subjects sub on sub.id = co.subject_id
join public.teachers t on t.id = se.teacher_id
join public.people tp on tp.id = t.person_id
left join public.rooms r on r.id = se.room_id
where cp.status = 'ACTIVE'
  and scp.status = 'ACTIVE';

-- Planning surface: every regular school slot can be inspected before assigning
-- a lesson. The actual no-overlap constraints remain authoritative.
create or replace view public.timetable_slot_usage
with (security_invoker = true)
as
select
  sp.school_id,
  se.academic_year_id,
  sp.id as period_id,
  sp.ordinal as period_ordinal,
  sp.code as period_code,
  sp.starts_at,
  sp.ends_at,
  d.day_of_week,
  count(*) filter (where se.status in ('DRAFT','ACTIVE')) as used_slots
from public.schedule_periods sp
cross join generate_series(1, 7) as d(day_of_week)
left join public.schedule_entries se
  on se.period_id = sp.id
 and se.day_of_week = d.day_of_week
 and se.school_id = sp.school_id
group by
  sp.school_id, se.academic_year_id, sp.id, sp.ordinal,
  sp.code, sp.starts_at, sp.ends_at, d.day_of_week;

-- Security boundary for the new projections.
alter table public.education_levels enable row level security;
alter table public.academic_cycles enable row level security;
alter table public.grade_levels enable row level security;
alter table public.academic_pathways enable row level security;
alter table public.class_group_leadership enable row level security;
alter table public.teacher_workload_targets enable row level security;

create policy education_levels_read
on public.education_levels for select to authenticated using (true);

create policy academic_cycles_read
on public.academic_cycles for select to authenticated using (true);

create policy grade_levels_read
on public.grade_levels for select to authenticated using (true);

create policy academic_pathways_read
on public.academic_pathways for select to authenticated
using (school_id is null or private.has_permission('operations.read', school_id));

create policy class_group_leadership_read
on public.class_group_leadership for select to authenticated
using (exists (
  select 1 from public.class_groups cg
  where cg.id = class_group_leadership.class_group_id
    and private.has_permission('operations.read', cg.school_id)
));

create policy teacher_workload_targets_read
on public.teacher_workload_targets for select to authenticated
using (exists (
  select 1 from public.academic_years ay
  join public.teachers t on t.id = teacher_workload_targets.teacher_id
  where ay.id = teacher_workload_targets.academic_year_id
    and private.has_permission('operations.read', ay.school_id)
));

grant select on public.education_levels, public.academic_cycles, public.grade_levels,
  public.academic_pathways, public.class_group_leadership, public.teacher_workload_targets,
  public.class_group_overview, public.class_group_students, public.class_group_teachers,
  public.teacher_workload_summary, public.class_timetable, public.teacher_timetable,
  public.student_timetable, public.timetable_slot_usage to authenticated;

-- Seed only the national structural levels/cycles/classes. Pathways remain
-- school/configuration data because offerings differ by institution and
-- curricular revision.
insert into public.education_levels (code, name, ordinal)
values
  ('EI', 'Centro Infantil', 1),
  ('EP', 'Ensino Primário', 2),
  ('ES', 'Ensino Secundário', 3)
on conflict (code) do update set name = excluded.name, ordinal = excluded.ordinal;

insert into public.academic_cycles (education_level_id, code, name, ordinal)
select el.id, v.code, v.name, v.ordinal
from public.education_levels el
cross join (values
  ('C1', '1.º Ciclo', 1),
  ('C2', '2.º Ciclo', 2)
) v(code, name, ordinal)
where el.code = 'ES'
on conflict (education_level_id, code)
do update set name = excluded.name, ordinal = excluded.ordinal;

insert into public.grade_levels (academic_cycle_id, code, name, ordinal)
select ac.id, v.code, v.name, v.ordinal
from public.academic_cycles ac
cross join (values
  ('7', '7.ª Classe', 1),
  ('8', '8.ª Classe', 2),
  ('9', '9.ª Classe', 3)
) v(code, name, ordinal)
join public.education_levels el on el.id = ac.education_level_id
where el.code = 'ES' and ac.code = 'C1'
on conflict (academic_cycle_id, code)
do update set name = excluded.name, ordinal = excluded.ordinal;

insert into public.grade_levels (academic_cycle_id, code, name, ordinal)
select ac.id, v.code, v.name, v.ordinal
from public.academic_cycles ac
cross join (values
  ('10', '10.ª Classe', 1),
  ('11', '11.ª Classe', 2),
  ('12', '12.ª Classe', 3)
) v(code, name, ordinal)
join public.education_levels el on el.id = ac.education_level_id
where el.code = 'ES' and ac.code = 'C2'
on conflict (academic_cycle_id, code)
do update set name = excluded.name, ordinal = excluded.ordinal;
