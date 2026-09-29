-- SIGE 0024 — Curriculum engine
-- Curriculum is configuration, not application code. It is versioned by
-- academic year and contextualized by grade/pathway.

create type public.curriculum_selection_mode as enum (
  'REQUIRED',
  'OPTIONAL',
  'CHOICE'
);

create table public.curriculum_areas (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete restrict,
  academic_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  code text not null,
  name text not null,
  ordinal integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, academic_cycle_id, code),
  constraint curriculum_areas_ordinal_ck check (ordinal > 0),
  constraint curriculum_areas_code_ck check (length(trim(code)) >= 1)
);

create table public.curriculum_choice_groups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  grade_level_id uuid not null references public.grade_levels(id) on delete restrict,
  pathway_id uuid references public.academic_pathways(id) on delete restrict,
  code text not null,
  name text not null,
  min_selections integer not null default 1,
  max_selections integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint curriculum_choice_min_ck check (min_selections >= 0),
  constraint curriculum_choice_max_ck check (max_selections >= min_selections),
  constraint curriculum_choice_code_ck check (length(trim(code)) >= 1)
);

create unique index if not exists curriculum_choice_groups_context_code_uidx
  on public.curriculum_choice_groups (
    academic_year_id,
    grade_level_id,
    coalesce(pathway_id, '00000000-0000-0000-0000-000000000000'::uuid),
    code
  );

alter table public.curriculum_subjects
  drop constraint if exists curriculum_subjects_academic_year_id_grade_level_id_subject_id_key;

alter table public.curriculum_subjects
  add column if not exists curriculum_area_id uuid references public.curriculum_areas(id) on delete restrict,
  add column if not exists selection_mode public.curriculum_selection_mode not null default 'REQUIRED',
  add column if not exists choice_group_id uuid references public.curriculum_choice_groups(id) on delete restrict,
  add column if not exists ordinal integer;

create unique index if not exists curriculum_subjects_context_subject_uidx
  on public.curriculum_subjects (
    academic_year_id,
    grade_level_id,
    subject_id,
    coalesce(pathway_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

create index if not exists curriculum_subjects_area_idx
  on public.curriculum_subjects (curriculum_area_id, ordinal);

create index if not exists curriculum_subjects_choice_group_idx
  on public.curriculum_subjects (choice_group_id);

alter table public.curriculum_subjects
  drop constraint if exists curriculum_subjects_mandatory_ck;

alter table public.curriculum_subjects
  add constraint curriculum_subjects_selection_consistency_ck
  check (
    (selection_mode = 'REQUIRED' and mandatory = true and choice_group_id is null)
    or
    (selection_mode = 'OPTIONAL' and mandatory = false)
    or
    (selection_mode = 'CHOICE' and mandatory = false and choice_group_id is not null)
  );

alter table public.curriculum_subjects
  add constraint curriculum_subjects_weekly_periods_ck
  check (weekly_periods is null or weekly_periods > 0);

create or replace function private.validate_curriculum_subject_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  grade_cycle uuid;
  area_cycle uuid;
  choice_year uuid;
  choice_grade uuid;
  choice_pathway uuid;
  row_pathway_cycle uuid;
  row_pathway_school uuid;
begin
  select gl.academic_cycle_id into grade_cycle
  from public.grade_levels gl
  where gl.id = new.grade_level_id;

  if grade_cycle is null then
    raise exception 'GRADE_LEVEL_NOT_FOUND';
  end if;

  if new.curriculum_area_id is not null then
    select ca.academic_cycle_id into area_cycle
    from public.curriculum_areas ca
    where ca.id = new.curriculum_area_id
      and ca.active;

    if area_cycle is null then raise exception 'CURRICULUM_AREA_NOT_FOUND'; end if;
    if area_cycle <> grade_cycle then
      raise exception 'CURRICULUM_AREA_CYCLE_MISMATCH';
    end if;
  end if;

  if new.pathway_id is not null then
    select ap.academic_cycle_id, ap.school_id
      into row_pathway_cycle, row_pathway_school
    from public.academic_pathways ap
    where ap.id = new.pathway_id
      and ap.active;

    if row_pathway_cycle is null then raise exception 'PATHWAY_NOT_FOUND'; end if;
    if row_pathway_cycle <> grade_cycle then
      raise exception 'CURRICULUM_PATHWAY_CYCLE_MISMATCH';
    end if;
    if row_pathway_school is not null and row_pathway_school <> new.school_id then
      raise exception 'CURRICULUM_PATHWAY_SCHOOL_MISMATCH';
    end if;
  end if;

  if new.choice_group_id is not null then
    select cg.academic_year_id, cg.grade_level_id, cg.pathway_id
      into choice_year, choice_grade, choice_pathway
    from public.curriculum_choice_groups cg
    where cg.id = new.choice_group_id
      and cg.active;

    if choice_year is null then raise exception 'CURRICULUM_CHOICE_GROUP_NOT_FOUND'; end if;
    if choice_year <> new.academic_year_id or choice_grade <> new.grade_level_id then
      raise exception 'CURRICULUM_CHOICE_CONTEXT_MISMATCH';
    end if;
    if choice_pathway is distinct from new.pathway_id then
      raise exception 'CURRICULUM_CHOICE_PATHWAY_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_curriculum_subject_context
  on public.curriculum_subjects;

create trigger trg_validate_curriculum_subject_context
before insert or update on public.curriculum_subjects
for each row execute function private.validate_curriculum_subject_context();

create or replace function public.configure_curriculum_subject(
  p_academic_year_id uuid,
  p_grade_level_id uuid,
  p_subject_id uuid,
  p_pathway_id uuid default null,
  p_curriculum_area_id uuid default null,
  p_selection_mode public.curriculum_selection_mode default 'REQUIRED',
  p_choice_group_id uuid default null,
  p_weekly_periods integer default null,
  p_ordinal integer default null,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  year_status public.academic_year_status;
  grade_cycle uuid;
  subject_school uuid;
  curriculum_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status
    into school_id, year_status
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if year_status not in ('DRAFT','OPEN') then
    raise exception 'ACADEMIC_YEAR_NOT_EDITABLE';
  end if;

  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_weekly_periods is not null and p_weekly_periods <= 0 then
    raise exception 'INVALID_WEEKLY_PERIODS';
  end if;
  if p_ordinal is not null and p_ordinal <= 0 then
    raise exception 'INVALID_CURRICULUM_ORDINAL';
  end if;

  select gl.academic_cycle_id into grade_cycle
  from public.grade_levels gl
  where gl.id = p_grade_level_id and gl.active;

  if grade_cycle is null then raise exception 'GRADE_LEVEL_NOT_FOUND'; end if;

  select s.school_id into subject_school
  from public.subjects s
  where s.id = p_subject_id and s.active;

  if not found then raise exception 'SUBJECT_NOT_FOUND'; end if;
  if subject_school is not null and subject_school <> school_id then
    raise exception 'SUBJECT_SCHOOL_MISMATCH';
  end if;

  if p_pathway_id is not null then
    if not exists (
      select 1 from public.academic_pathways ap
      where ap.id = p_pathway_id
        and ap.active
        and ap.academic_cycle_id = grade_cycle
        and (ap.school_id is null or ap.school_id = school_id)
    ) then
      raise exception 'PATHWAY_CONTEXT_INVALID';
    end if;
  end if;

  if p_selection_mode = 'CHOICE' and p_choice_group_id is null then
    raise exception 'CHOICE_GROUP_REQUIRED';
  end if;
  if p_selection_mode <> 'CHOICE' and p_choice_group_id is not null then
    raise exception 'CHOICE_GROUP_NOT_ALLOWED';
  end if;

  command_state := private.begin_command(
    'configure_curriculum_subject', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.curriculum_subjects (
    school_id, academic_year_id, grade_level_id, subject_id, pathway_id,
    curriculum_area_id, selection_mode, choice_group_id,
    weekly_periods, mandatory, ordinal, active
  )
  values (
    school_id, p_academic_year_id, p_grade_level_id, p_subject_id, p_pathway_id,
    p_curriculum_area_id, p_selection_mode, p_choice_group_id,
    p_weekly_periods, p_selection_mode = 'REQUIRED', p_ordinal, true
  )
  on conflict (
    academic_year_id, grade_level_id, subject_id,
    coalesce(pathway_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  do update set
    curriculum_area_id = excluded.curriculum_area_id,
    selection_mode = excluded.selection_mode,
    choice_group_id = excluded.choice_group_id,
    weekly_periods = excluded.weekly_periods,
    mandatory = excluded.mandatory,
    ordinal = excluded.ordinal,
    active = true
  returning id into curriculum_id;

  result := jsonb_build_object(
    'curriculum_subject_id', curriculum_id,
    'academic_year_id', p_academic_year_id,
    'grade_level_id', p_grade_level_id,
    'subject_id', p_subject_id,
    'pathway_id', p_pathway_id,
    'selection_mode', p_selection_mode,
    'weekly_periods', p_weekly_periods
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CONFIGURE_CURRICULUM_SUBJECT',
    'curriculum_subject', curriculum_id, result
  );

  perform private.complete_command(
    'configure_curriculum_subject', school_id, p_idempotency_key, p_request_hash
  );

  return result;
end;
$$;

revoke all on function private.validate_curriculum_subject_context() from public;
revoke all on function public.configure_curriculum_subject(
  uuid, uuid, uuid, uuid, uuid, public.curriculum_selection_mode, uuid, integer, integer, text, text
) from public;

grant execute on function public.configure_curriculum_subject(
  uuid, uuid, uuid, uuid, uuid, public.curriculum_selection_mode, uuid, integer, integer, text, text
) to authenticated;

revoke insert, update, delete on public.curriculum_areas from authenticated;
revoke insert, update, delete on public.curriculum_choice_groups from authenticated;
revoke insert, update, delete on public.curriculum_subjects from authenticated;

grant select on public.curriculum_areas to authenticated;
grant select on public.curriculum_choice_groups to authenticated;
grant select on public.curriculum_subjects to authenticated;

create policy curriculum_areas_read
on public.curriculum_areas
for select to authenticated
using (
  school_id is null
  or private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
);

create policy curriculum_choice_groups_read
on public.curriculum_choice_groups
for select to authenticated
using (
  private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
);

create policy curriculum_subjects_read
on public.curriculum_subjects
for select to authenticated
using (
  private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
  or private.has_permission('assessment.read', school_id)
);

alter function public.configure_curriculum_subject(
  uuid, uuid, uuid, uuid, uuid, public.curriculum_selection_mode, uuid, integer, integer, text, text
) set search_path = '';
