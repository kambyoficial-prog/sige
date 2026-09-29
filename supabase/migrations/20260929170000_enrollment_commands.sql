-- SIGE 0016 — Transactional enrollment commands
--
-- These are deliberately narrow domain commands. They are not generic CRUD RPCs.
-- Each command:
--   1. authenticates the actor through auth.uid()
--   2. authorizes the school scope
--   3. serializes the relevant aggregate
--   4. mutates state
--   5. writes audit
--   6. stores the idempotent result
--   7. commits atomically

create or replace function private.begin_command(
  p_command_name text,
  p_school_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  existing private.command_idempotency%rowtype;
  actor uuid := (select auth.uid());
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_command_name is null or length(trim(p_command_name)) < 2 then
    raise exception 'INVALID_COMMAND';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  select *
    into existing
  from private.command_idempotency
  where actor_auth_user_id = actor
    and school_id = p_school_id
    and command_name = p_command_name
    and idempotency_key = p_idempotency_key
  for update;

  if found then
    if existing.request_hash is distinct from p_request_hash then
      raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';
    end if;

    if existing.status = 'COMPLETED' then
      return jsonb_build_object(
        'replayed', true,
        'status', existing.status,
        'result', existing.result_payload
      );
    end if;

    if existing.status = 'STARTED' then
      raise exception 'COMMAND_ALREADY_IN_PROGRESS';
    end if;

    raise exception 'COMMAND_PREVIOUSLY_FAILED';
  end if;

  insert into private.command_idempotency (
    actor_auth_user_id,
    school_id,
    command_name,
    idempotency_key,
    request_hash,
    status
  )
  values (
    actor,
    p_school_id,
    p_command_name,
    p_idempotency_key,
    p_request_hash,
    'STARTED'
  );

  return jsonb_build_object('replayed', false, 'status', 'STARTED');
end;
$$;

create or replace function private.complete_command(
  p_command_name text,
  p_school_id uuid,
  p_idempotency_key text,
  p_result jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  update private.command_idempotency
     set status = 'COMPLETED',
         result_payload = p_result,
         completed_at = now()
   where actor_auth_user_id = (select auth.uid())
     and school_id = p_school_id
     and command_name = p_command_name
     and idempotency_key = p_idempotency_key;

  if not found then
    raise exception 'IDEMPOTENCY_RECORD_NOT_FOUND';
  end if;
end;
$$;

create or replace function public.enroll_student(
  p_student_id uuid,
  p_academic_year_id uuid,
  p_grade_level_id uuid,
  p_entry_type public.enrollment_entry_type default 'INITIAL',
  p_enrolled_on date default current_date,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  student_school uuid;
  year_school uuid;
  year_status public.academic_year_status;
  enrollment_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select s.school_id
    into student_school
  from public.students s
  where s.id = p_student_id
  for update;

  if student_school is null then
    raise exception 'STUDENT_NOT_FOUND';
  end if;

  select ay.school_id, ay.status
    into year_school, year_status
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for share;

  if year_school is null then
    raise exception 'ACADEMIC_YEAR_NOT_FOUND';
  end if;

  if student_school <> year_school then
    raise exception 'SCHOOL_CONTEXT_MISMATCH';
  end if;

  if year_status <> 'OPEN' then
    raise exception 'ACADEMIC_YEAR_NOT_OPEN';
  end if;

  if not (select private.has_permission('enrollment.manage', student_school)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  command_state := private.begin_command(
    'enroll_student',
    student_school,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  if exists (
    select 1
    from public.student_enrollments e
    where e.student_id = p_student_id
      and e.academic_year_id = p_academic_year_id
  ) then
    raise exception 'ENROLLMENT_ALREADY_EXISTS';
  end if;

  if not exists (
    select 1
    from public.grade_levels gl
    where gl.id = p_grade_level_id
      and gl.active
  ) then
    raise exception 'GRADE_LEVEL_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.grade_levels gl
    join public.curriculum_subjects cs
      on cs.grade_level_id = gl.id
     and cs.academic_year_id = p_academic_year_id
    where gl.id = p_grade_level_id
      and gl.active
      and cs.active
  ) then
    -- A grade can exist before curriculum is configured. Enrollment itself
    -- remains a valid operation; curriculum completeness is enforced before
    -- class/course opening rather than silently inventing subjects here.
    null;
  end if;

  insert into public.student_enrollments (
    student_id,
    academic_year_id,
    grade_level_id,
    status,
    entry_type,
    enrolled_on
  )
  values (
    p_student_id,
    p_academic_year_id,
    p_grade_level_id,
    'ACTIVE',
    p_entry_type,
    p_enrolled_on
  )
  returning id into enrollment_id;

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
    student_school,
    actor,
    'ENROLL_STUDENT',
    'student_enrollment',
    enrollment_id,
    null,
    jsonb_build_object(
      'student_id', p_student_id,
      'academic_year_id', p_academic_year_id,
      'grade_level_id', p_grade_level_id,
      'entry_type', p_entry_type,
      'enrolled_on', p_enrolled_on
    )
  );

  result := jsonb_build_object(
    'enrollment_id', enrollment_id,
    'student_id', p_student_id,
    'academic_year_id', p_academic_year_id,
    'grade_level_id', p_grade_level_id,
    'status', 'ACTIVE'
  );

  perform private.complete_command(
    'enroll_student',
    student_school,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

create or replace function public.place_student_in_class(
  p_enrollment_id uuid,
  p_class_group_id uuid,
  p_starts_on date default current_date,
  p_ends_on date default null,
  p_reason text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  enrollment_school uuid;
  enrollment_year uuid;
  enrollment_grade uuid;
  enrollment_status public.enrollment_status;
  class_school uuid;
  class_year uuid;
  class_grade uuid;
  class_status public.class_group_status;
  capacity integer;
  occupied integer;
  placement_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select s.school_id, e.academic_year_id, e.grade_level_id, e.status
    into enrollment_school, enrollment_year, enrollment_grade, enrollment_status
  from public.student_enrollments e
  join public.students s on s.id = e.student_id
  where e.id = p_enrollment_id
  for update;

  if enrollment_school is null then
    raise exception 'ENROLLMENT_NOT_FOUND';
  end if;

  if enrollment_status not in ('ACTIVE','TRANSFERRED_IN') then
    raise exception 'ENROLLMENT_NOT_PLACABLE';
  end if;

  select cg.school_id, cg.academic_year_id, cg.grade_level_id, cg.status, cg.capacity
    into class_school, class_year, class_grade, class_status, capacity
  from public.class_groups cg
  where cg.id = p_class_group_id
  for update;

  if class_school is null then
    raise exception 'CLASS_GROUP_NOT_FOUND';
  end if;

  if enrollment_school <> class_school
     or enrollment_year <> class_year
     or enrollment_grade <> class_grade then
    raise exception 'CLASS_CONTEXT_MISMATCH';
  end if;

  if class_status not in ('OPEN','ACTIVE') then
    raise exception 'CLASS_GROUP_NOT_OPEN';
  end if;

  if not (select private.has_permission('enrollment.manage', enrollment_school)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  command_state := private.begin_command(
    'place_student_in_class',
    enrollment_school,
    p_idempotency_key,
    p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  select count(*)::integer
    into occupied
  from public.class_placements cp
  where cp.class_group_id = p_class_group_id
    and cp.status = 'ACTIVE'
    and daterange(
      cp.starts_on,
      coalesce(cp.ends_on + 1, '9999-12-31'::date),
      '[)'
    ) &&
    daterange(
      p_starts_on,
      coalesce(p_ends_on + 1, '9999-12-31'::date),
      '[)'
    );

  if capacity is not null and occupied >= capacity then
    raise exception 'CLASS_CAPACITY_REACHED';
  end if;

  insert into public.class_placements (
    enrollment_id,
    class_group_id,
    starts_on,
    ends_on,
    status,
    reason
  )
  values (
    p_enrollment_id,
    p_class_group_id,
    p_starts_on,
    p_ends_on,
    'ACTIVE',
    p_reason
  )
  returning id into placement_id;

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
    enrollment_school,
    actor,
    'PLACE_STUDENT_IN_CLASS',
    'class_placement',
    placement_id,
    p_reason,
    jsonb_build_object(
      'enrollment_id', p_enrollment_id,
      'class_group_id', p_class_group_id,
      'starts_on', p_starts_on,
      'ends_on', p_ends_on
    )
  );

  result := jsonb_build_object(
    'placement_id', placement_id,
    'enrollment_id', p_enrollment_id,
    'class_group_id', p_class_group_id,
    'status', 'ACTIVE'
  );

  perform private.complete_command(
    'place_student_in_class',
    enrollment_school,
    p_idempotency_key,
    result
  );

  return result;
end;
$$;

revoke all on function private.begin_command(text, uuid, text, text) from public;
revoke all on function private.complete_command(text, uuid, text, jsonb) from public;
revoke all on function public.enroll_student(uuid, uuid, uuid, public.enrollment_entry_type, date, text, text) from public;
revoke all on function public.place_student_in_class(uuid, uuid, date, date, text, text, text) from public;

grant execute on function public.enroll_student(uuid, uuid, uuid, public.enrollment_entry_type, date, text, text) to authenticated;
grant execute on function public.place_student_in_class(uuid, uuid, date, date, text, text, text) to authenticated;
