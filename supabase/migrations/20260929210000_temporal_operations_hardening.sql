-- SIGE 0027 — Temporal hardening across academic operations
--
-- A closed academic year is immutable through every operational aggregate,
-- not only assessments. Historical data remains readable; mutations require
-- an explicit future correction workflow.
--
-- This migration also fixes an idempotency completion bug in
-- generate_class_offerings where the request hash was previously stored as
-- the command result.

create or replace function private.guard_closed_year_direct()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_academic_year_mutable(
    coalesce(new.academic_year_id, old.academic_year_id)
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function private.guard_closed_year_assessment_periods()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_academic_year_mutable(
    coalesce(new.academic_year_id, old.academic_year_id)
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function private.guard_closed_year_via_enrollment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_id uuid;
begin
  select e.academic_year_id
    into year_id
  from public.student_enrollments e
  where e.id = coalesce(new.enrollment_id, old.enrollment_id);

  perform private.assert_academic_year_mutable(year_id);

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function private.guard_closed_year_via_class_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_id uuid;
begin
  select cg.academic_year_id
    into year_id
  from public.class_groups cg
  where cg.id = coalesce(new.class_group_id, old.class_group_id);

  perform private.assert_academic_year_mutable(year_id);

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function private.guard_closed_year_via_offering()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_id uuid;
begin
  select co.academic_year_id
    into year_id
  from public.course_offerings co
  where co.id = coalesce(new.course_offering_id, old.course_offering_id);

  perform private.assert_academic_year_mutable(year_id);

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_closed_year_class_groups on public.class_groups;
create trigger trg_guard_closed_year_class_groups
before insert or update or delete on public.class_groups
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_course_offerings on public.course_offerings;
create trigger trg_guard_closed_year_course_offerings
before insert or update or delete on public.course_offerings
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_curriculum_subjects on public.curriculum_subjects;
create trigger trg_guard_closed_year_curriculum_subjects
before insert or update or delete on public.curriculum_subjects
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_choice_groups on public.curriculum_choice_groups;
create trigger trg_guard_closed_year_choice_groups
before insert or update or delete on public.curriculum_choice_groups
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_workload_targets on public.teacher_workload_targets;
create trigger trg_guard_closed_year_workload_targets
before insert or update or delete on public.teacher_workload_targets
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_enrollments on public.student_enrollments;
create trigger trg_guard_closed_year_enrollments
before insert or update or delete on public.student_enrollments
for each row execute function private.guard_closed_year_direct();

drop trigger if exists trg_guard_closed_year_assessment_periods on public.assessment_periods;
create trigger trg_guard_closed_year_assessment_periods
before insert or update or delete on public.assessment_periods
for each row execute function private.guard_closed_year_assessment_periods();

drop trigger if exists trg_guard_closed_year_class_placements on public.class_placements;
create trigger trg_guard_closed_year_class_placements
before insert or update or delete on public.class_placements
for each row execute function private.guard_closed_year_via_enrollment();

drop trigger if exists trg_guard_closed_year_student_participations on public.student_course_participations;
create trigger trg_guard_closed_year_student_participations
before insert or update or delete on public.student_course_participations
for each row execute function private.guard_closed_year_via_offering();

drop trigger if exists trg_guard_closed_year_teacher_assignments on public.teacher_assignments;
create trigger trg_guard_closed_year_teacher_assignments
before insert or update or delete on public.teacher_assignments
for each row execute function private.guard_closed_year_via_offering();

drop trigger if exists trg_guard_closed_year_class_group_leadership on public.class_group_leadership;
create trigger trg_guard_closed_year_class_group_leadership
before insert or update or delete on public.class_group_leadership
for each row execute function private.guard_closed_year_via_class_group();

revoke all on function private.guard_closed_year_direct() from public;
revoke all on function private.guard_closed_year_assessment_periods() from public;
revoke all on function private.guard_closed_year_via_enrollment() from public;
revoke all on function private.guard_closed_year_via_class_group() from public;
revoke all on function private.guard_closed_year_via_offering() from public;

create or replace function public.generate_class_offerings(
  p_class_group_id uuid,
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
  year_id uuid;
  year_status public.academic_year_status;
  grade_id uuid;
  pathway_id uuid;
  class_status public.class_group_status;
  created_count integer := 0;
  offering_id uuid;
  cs record;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  select
    cg.school_id,
    cg.academic_year_id,
    ay.status,
    cg.grade_level_id,
    cg.pathway_id,
    cg.status
    into
      school_id,
      year_id,
      year_status,
      grade_id,
      pathway_id,
      class_status
  from public.class_groups cg
  join public.academic_years ay on ay.id = cg.academic_year_id
  where cg.id = p_class_group_id
  for update of cg, ay;

  if school_id is null then
    raise exception 'CLASS_GROUP_NOT_FOUND';
  end if;

  if year_status not in ('DRAFT','OPEN') then
    raise exception 'ACADEMIC_YEAR_NOT_EDITABLE';
  end if;

  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if class_status in ('CLOSED','CANCELLED') then
    raise exception 'CLASS_GROUP_NOT_OPEN';
  end if;

  command_state := private.begin_command(
    'generate_class_offerings',
    school_id,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  for cs in
    select distinct on (cs.subject_id)
      cs.id,
      cs.subject_id
    from public.curriculum_subjects cs
    where cs.school_id = school_id
      and cs.academic_year_id = year_id
      and cs.grade_level_id = grade_id
      and cs.active
      and (
        cs.pathway_id is null
        or cs.pathway_id = pathway_id
      )
    order by
      cs.subject_id,
      (cs.pathway_id is null),
      cs.id
  loop
    if not exists (
      select 1
      from public.course_offerings co
      where co.class_group_id = p_class_group_id
        and co.subject_id = cs.subject_id
    ) then
      insert into public.course_offerings (
        school_id,
        academic_year_id,
        class_group_id,
        subject_id,
        curriculum_subject_id,
        status
      )
      values (
        school_id,
        year_id,
        p_class_group_id,
        cs.subject_id,
        cs.id,
        'DRAFT'
      )
      returning id into offering_id;

      created_count := created_count + 1;
    end if;
  end loop;

  result := jsonb_build_object(
    'class_group_id',
    p_class_group_id,
    'created_offerings',
    created_count
  );

  insert into public.audit_events (
    school_id,
    actor_auth_user_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    school_id,
    actor,
    'GENERATE_CLASS_OFFERINGS',
    'class_group',
    p_class_group_id,
    result
  );

  perform private.complete_command(
    'generate_class_offerings',
    school_id,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

revoke all on function public.generate_class_offerings(uuid,text,text) from public;
grant execute on function public.generate_class_offerings(uuid,text,text) to authenticated;

comment on function private.assert_academic_year_mutable(uuid) is
  'Final temporal guard: operational records associated with a CLOSED academic year are immutable. Historical reads remain allowed.';
