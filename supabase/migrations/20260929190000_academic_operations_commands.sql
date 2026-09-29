-- SIGE 0023 — Academic operations: class lifecycle, offerings, teacher assignment and class transfer
--
-- This layer turns the academic structure into controlled operational commands.
-- It deliberately keeps curriculum, class, offering, staffing and student
-- participation as separate aggregates.

-- A section letter/code is unique only inside the same curricular pathway.
-- The same section code may legitimately exist in different pathways.
drop index if exists public.class_groups_year_grade_section_uidx;

create unique index if not exists class_groups_year_grade_section_pathway_uidx
  on public.class_groups (
    academic_year_id,
    grade_level_id,
    lower(section_code),
    coalesce(pathway_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where section_code is not null;

-- PostgreSQL UNIQUE treats NULL school_id values as distinct. Pathways need
-- deterministic uniqueness for both global and school-scoped definitions.
create unique index if not exists academic_pathways_cycle_code_scope_uidx
  on public.academic_pathways (
    academic_cycle_id,
    lower(code),
    coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

-- One teacher assignment to the same offering is temporal. The same teacher
-- may teach another offering at the same time; timetable constraints decide
-- whether those lessons can occupy the same slot.
alter table public.teacher_assignments
  add constraint teacher_assignments_offering_teacher_no_overlap
  exclude using gist (
    (course_offering_id) with =,
    (teacher_id) with =,
    daterange(starts_on, coalesce(ends_on + 1, '9999-12-31'::date), '[)') with &&
  )
  where (active);

create index if not exists course_offerings_class_idx
  on public.course_offerings (class_group_id, status, subject_id);

create index if not exists curriculum_subjects_grade_year_active_idx
  on public.curriculum_subjects (academic_year_id, grade_level_id, active, pathway_id);

create or replace function private.validate_course_offering_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  class_school uuid;
  class_year uuid;
  class_grade uuid;
  class_pathway uuid;
  subject_school uuid;
  curriculum_school uuid;
  curriculum_year uuid;
  curriculum_grade uuid;
  curriculum_pathway uuid;
begin
  select cg.school_id, cg.academic_year_id, cg.grade_level_id, cg.pathway_id
    into class_school, class_year, class_grade, class_pathway
  from public.class_groups cg
  where cg.id = new.class_group_id;

  if class_school is null then
    raise exception 'CLASS_GROUP_NOT_FOUND';
  end if;

  if new.school_id <> class_school or new.academic_year_id <> class_year then
    raise exception 'COURSE_OFFERING_CLASS_CONTEXT_MISMATCH';
  end if;

  select s.school_id
    into subject_school
  from public.subjects s
  where s.id = new.subject_id;

  if not found then
    raise exception 'SUBJECT_NOT_FOUND';
  end if;

  if subject_school is not null and subject_school <> class_school then
    raise exception 'COURSE_OFFERING_SUBJECT_SCHOOL_MISMATCH';
  end if;

  if new.curriculum_subject_id is not null then
    select cs.school_id, cs.academic_year_id, cs.grade_level_id, cs.pathway_id
      into curriculum_school, curriculum_year, curriculum_grade, curriculum_pathway
    from public.curriculum_subjects cs
    where cs.id = new.curriculum_subject_id
      and cs.active;

    if curriculum_school is null then
      raise exception 'CURRICULUM_SUBJECT_NOT_FOUND';
    end if;

    if curriculum_school <> class_school
       or curriculum_year <> class_year
       or curriculum_grade <> class_grade
       or curriculum_pathway is distinct from class_pathway then
      raise exception 'COURSE_OFFERING_CURRICULUM_CONTEXT_MISMATCH';
    end if;

    if not exists (
      select 1
      from public.curriculum_subjects cs
      where cs.id = new.curriculum_subject_id
        and cs.subject_id = new.subject_id
    ) then
      raise exception 'COURSE_OFFERING_SUBJECT_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_course_offering_context
  on public.course_offerings;

create trigger trg_validate_course_offering_context
before insert or update on public.course_offerings
for each row execute function private.validate_course_offering_context();

create or replace function public.create_class_group(
  p_academic_year_id uuid,
  p_grade_level_id uuid,
  p_section_code text,
  p_pathway_id uuid default null,
  p_shift text default null,
  p_capacity integer default null,
  p_name text default null,
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
  year_start date;
  year_end date;
  grade_cycle uuid;
  pathway_cycle uuid;
  pathway_school uuid;
  class_group_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status, ay.starts_on, ay.ends_on
    into school_id, year_status, year_start, year_end
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if year_status not in ('DRAFT','OPEN') then raise exception 'ACADEMIC_YEAR_NOT_EDITABLE'; end if;

  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  if p_section_code is null or length(trim(p_section_code)) = 0 then
    raise exception 'SECTION_CODE_REQUIRED';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'INVALID_CLASS_CAPACITY';
  end if;

  select gl.academic_cycle_id
    into grade_cycle
  from public.grade_levels gl
  where gl.id = p_grade_level_id
    and gl.active;

  if grade_cycle is null then raise exception 'GRADE_LEVEL_NOT_FOUND'; end if;

  if p_pathway_id is not null then
    select ap.academic_cycle_id, ap.school_id
      into pathway_cycle, pathway_school
    from public.academic_pathways ap
    where ap.id = p_pathway_id
      and ap.active;

    if pathway_cycle is null then raise exception 'PATHWAY_NOT_FOUND'; end if;
    if pathway_cycle <> grade_cycle then raise exception 'CLASS_GROUP_PATHWAY_CYCLE_MISMATCH'; end if;
    if pathway_school is not null and pathway_school <> school_id then
      raise exception 'CLASS_GROUP_PATHWAY_SCHOOL_MISMATCH';
    end if;
  end if;

  command_state := private.begin_command(
    'create_class_group', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.class_groups (
    school_id,
    academic_year_id,
    grade_level_id,
    pathway_id,
    section_code,
    shift,
    capacity,
    name,
    status
  )
  values (
    school_id,
    p_academic_year_id,
    p_grade_level_id,
    p_pathway_id,
    upper(trim(p_section_code)),
    p_shift,
    p_capacity,
    nullif(trim(p_name), ''),
    'DRAFT'
  )
  returning id into class_group_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CREATE_CLASS_GROUP', 'class_group', class_group_id,
    jsonb_build_object(
      'academic_year_id', p_academic_year_id,
      'grade_level_id', p_grade_level_id,
      'pathway_id', p_pathway_id,
      'section_code', upper(trim(p_section_code)),
      'shift', p_shift,
      'capacity', p_capacity,
      'name', nullif(trim(p_name), '')
    )
  );

  result := jsonb_build_object(
    'class_group_id', class_group_id,
    'status', 'DRAFT'
  );

  perform private.complete_command(
    'create_class_group', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.update_class_group(
  p_class_group_id uuid,
  p_section_code text default null,
  p_pathway_id uuid default null,
  p_shift text default null,
  p_capacity integer default null,
  p_name text default null,
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
  current_status public.class_group_status;
  current_pathway uuid;
  grade_id uuid;
  year_id uuid;
  grade_cycle uuid;
  pathway_cycle uuid;
  pathway_school uuid;
  has_students boolean;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select cg.school_id, cg.status, cg.pathway_id, cg.grade_level_id, cg.academic_year_id
    into school_id, current_status, current_pathway, grade_id, year_id
  from public.class_groups cg
  where cg.id = p_class_group_id
  for update;

  if school_id is null then raise exception 'CLASS_GROUP_NOT_FOUND'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if current_status in ('CLOSED','CANCELLED') then
    raise exception 'CLASS_GROUP_NOT_EDITABLE';
  end if;
  if p_section_code is null or length(trim(p_section_code)) = 0 then
    raise exception 'SECTION_CODE_REQUIRED';
  end if;
  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'INVALID_CLASS_CAPACITY';
  end if;

  select gl.academic_cycle_id into grade_cycle
  from public.grade_levels gl where gl.id = grade_id;

  if p_pathway_id is not null then
    select ap.academic_cycle_id, ap.school_id into pathway_cycle, pathway_school
    from public.academic_pathways ap
    where ap.id = p_pathway_id and ap.active;

    if pathway_cycle is null then raise exception 'PATHWAY_NOT_FOUND'; end if;
    if pathway_cycle <> grade_cycle then raise exception 'CLASS_GROUP_PATHWAY_CYCLE_MISMATCH'; end if;
    if pathway_school is not null and pathway_school <> school_id then
      raise exception 'CLASS_GROUP_PATHWAY_SCHOOL_MISMATCH';
    end if;
  end if;

  select exists (
    select 1 from public.class_placements cp
    where cp.class_group_id = p_class_group_id
      and cp.status = 'ACTIVE'
  ) into has_students;

  if has_students and p_pathway_id is distinct from current_pathway then
    raise exception 'CLASS_PATHWAY_CHANGE_REQUIRES_EMPTY_CLASS';
  end if;

  command_state := private.begin_command(
    'update_class_group', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.class_groups
     set section_code = upper(trim(p_section_code)),
         pathway_id = p_pathway_id,
         shift = p_shift,
         capacity = p_capacity,
         name = nullif(trim(p_name), ''),
         updated_at = now()
   where id = p_class_group_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'UPDATE_CLASS_GROUP', 'class_group', p_class_group_id,
    jsonb_build_object(
      'section_code', upper(trim(p_section_code)),
      'pathway_id', p_pathway_id,
      'shift', p_shift,
      'capacity', p_capacity,
      'name', nullif(trim(p_name), '')
    )
  );

  result := jsonb_build_object('class_group_id', p_class_group_id, 'updated', true);

  perform private.complete_command(
    'update_class_group', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.close_class_group(
  p_class_group_id uuid,
  p_closed_on date default current_date,
  p_reason text default null,
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
  year_start date;
  year_end date;
  current_status public.class_group_status;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select cg.school_id, ay.starts_on, ay.ends_on, cg.status
    into school_id, year_start, year_end, current_status
  from public.class_groups cg
  join public.academic_years ay on ay.id = cg.academic_year_id
  where cg.id = p_class_group_id
  for update;

  if school_id is null then raise exception 'CLASS_GROUP_NOT_FOUND'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if p_closed_on < year_start or p_closed_on > year_end then
    raise exception 'CLASS_CLOSE_DATE_OUTSIDE_ACADEMIC_YEAR';
  end if;
  if current_status in ('CLOSED','CANCELLED') then
    raise exception 'CLASS_GROUP_ALREADY_CLOSED';
  end if;

  command_state := private.begin_command(
    'close_class_group', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  update public.class_groups
     set status = 'CLOSED', updated_at = now()
   where id = p_class_group_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, reason, after_data
  )
  values (
    school_id, actor, 'CLOSE_CLASS_GROUP', 'class_group', p_class_group_id,
    nullif(trim(p_reason), ''),
    jsonb_build_object('closed_on', p_closed_on)
  );

  result := jsonb_build_object(
    'class_group_id', p_class_group_id, 'status', 'CLOSED', 'closed_on', p_closed_on
  );

  perform private.complete_command(
    'close_class_group', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

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
  grade_id uuid;
  pathway_id uuid;
  class_status public.class_group_status;
  created_count integer := 0;
  offering_id uuid;
  cs record;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select cg.school_id, cg.academic_year_id, cg.grade_level_id, cg.pathway_id, cg.status
    into school_id, year_id, grade_id, pathway_id, class_status
  from public.class_groups cg
  where cg.id = p_class_group_id
  for update;

  if school_id is null then raise exception 'CLASS_GROUP_NOT_FOUND'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if class_status in ('CLOSED','CANCELLED') then
    raise exception 'CLASS_GROUP_NOT_OPEN'; end if;

  command_state := private.begin_command(
    'generate_class_offerings', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  for cs in
    select distinct on (cs.subject_id)
      cs.id, cs.subject_id
    from public.curriculum_subjects cs
    where cs.school_id = school_id
      and cs.academic_year_id = year_id
      and cs.grade_level_id = grade_id
      and cs.active
      and (
        cs.pathway_id is null
        or cs.pathway_id = pathway_id
      )
    order by cs.subject_id, (cs.pathway_id is null), cs.id
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
    'class_group_id', p_class_group_id,
    'created_offerings', created_count
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'GENERATE_CLASS_OFFERINGS', 'class_group', p_class_group_id,
    result
  );

  perform private.complete_command(
    'generate_class_offerings', school_id, p_idempotency_key, p_request_hash
  );

  return result;
end;
$$;

create or replace function public.assign_teacher_to_offering(
  p_course_offering_id uuid,
  p_teacher_id uuid,
  p_starts_on date,
  p_ends_on date default null,
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
  year_start date;
  year_end date;
  offering_status public.course_offering_status;
  teacher_school uuid;
  assignment_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id, co.status
    into school_id, year_id, offering_status
  from public.course_offerings co
  where co.id = p_course_offering_id
  for update;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  if offering_status in ('CLOSED','CANCELLED') then
    raise exception 'COURSE_OFFERING_NOT_ASSIGNABLE';
  end if;

  select ay.starts_on, ay.ends_on
    into year_start, year_end
  from public.academic_years ay
  where ay.id = year_id;

  if p_starts_on < year_start
     or p_starts_on > year_end
     or (p_ends_on is not null and (p_ends_on < p_starts_on or p_ends_on > year_end)) then
    raise exception 'TEACHER_ASSIGNMENT_DATES_OUTSIDE_ACADEMIC_YEAR';
  end if;

  select t.school_id into teacher_school
  from public.teachers t
  where t.id = p_teacher_id
    and t.status = 'ACTIVE'
  for share;

  if teacher_school is null then raise exception 'TEACHER_NOT_FOUND'; end if;
  if teacher_school <> school_id then raise exception 'TEACHER_SCHOOL_MISMATCH'; end if;

  if not (select private.has_permission('operations.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'assign_teacher_to_offering', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.teacher_assignments (
    teacher_id, course_offering_id, starts_on, ends_on, active
  )
  values (
    p_teacher_id, p_course_offering_id, p_starts_on, p_ends_on, true
  )
  returning id into assignment_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'ASSIGN_TEACHER_TO_OFFERING', 'teacher_assignment', assignment_id,
    jsonb_build_object(
      'course_offering_id', p_course_offering_id,
      'teacher_id', p_teacher_id,
      'starts_on', p_starts_on,
      'ends_on', p_ends_on
    )
  );

  result := jsonb_build_object(
    'teacher_assignment_id', assignment_id,
    'course_offering_id', p_course_offering_id,
    'teacher_id', p_teacher_id
  );

  perform private.complete_command(
    'assign_teacher_to_offering', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.transfer_student_class(
  p_enrollment_id uuid,
  p_target_class_group_id uuid,
  p_transfer_on date,
  p_reason text,
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
  grade_id uuid;
  enrollment_status public.enrollment_status;
  current_placement_id uuid;
  current_class_id uuid;
  current_starts_on date;
  target_year_id uuid;
  target_grade_id uuid;
  target_status public.class_group_status;
  target_capacity integer;
  target_occupied integer;
  year_start date;
  year_end date;
  new_placement_id uuid;
  closed_participations integer := 0;
  created_participations integer := 0;
  offering record;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'TRANSFER_REASON_REQUIRED';
  end if;

  select s.school_id, e.academic_year_id, e.grade_level_id, e.status
    into school_id, year_id, grade_id, enrollment_status
  from public.student_enrollments e
  join public.students s on s.id = e.student_id
  where e.id = p_enrollment_id
  for update;

  if school_id is null then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
  if enrollment_status not in ('ACTIVE','TRANSFERRED_IN') then
    raise exception 'ENROLLMENT_NOT_TRANSFERABLE';
  end if;

  select cp.id, cp.class_group_id, cp.starts_on
    into current_placement_id, current_class_id, current_starts_on
  from public.class_placements cp
  where cp.enrollment_id = p_enrollment_id
    and cp.status = 'ACTIVE'
    and cp.starts_on <= p_transfer_on
    and (cp.ends_on is null or cp.ends_on >= p_transfer_on)
  order by cp.starts_on desc
  limit 1
  for update;

  if current_placement_id is null then raise exception 'CURRENT_CLASS_PLACEMENT_NOT_FOUND'; end if;

  select cg.academic_year_id, cg.grade_level_id, cg.status, cg.capacity
    into target_year_id, target_grade_id, target_status, target_capacity
  from public.class_groups cg
  where cg.id = p_target_class_group_id
    and cg.school_id = school_id
  for update;

  if target_year_id is null then raise exception 'TARGET_CLASS_NOT_FOUND'; end if;
  if target_year_id <> year_id or target_grade_id <> grade_id then
    raise exception 'TRANSFER_TARGET_CONTEXT_MISMATCH';
  end if;
  if p_target_class_group_id = current_class_id then
    raise exception 'TRANSFER_TARGET_IS_CURRENT_CLASS';
  end if;
  if target_status not in ('OPEN','ACTIVE') then raise exception 'TARGET_CLASS_NOT_OPEN'; end if;

  select ay.starts_on, ay.ends_on into year_start, year_end
  from public.academic_years ay where ay.id = year_id;

  if p_transfer_on < year_start or p_transfer_on > year_end then
    raise exception 'TRANSFER_DATE_OUTSIDE_ACADEMIC_YEAR';
  end if;
  if p_transfer_on <= current_starts_on then
    raise exception 'TRANSFER_DATE_MUST_FOLLOW_CURRENT_PLACEMENT';
  end if;

  if not (select private.has_permission('enrollment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'transfer_student_class', school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  select count(*)::integer into target_occupied
  from public.class_placements cp
  where cp.class_group_id = p_target_class_group_id
    and cp.status = 'ACTIVE'
    and daterange(cp.starts_on, coalesce(cp.ends_on + 1, '9999-12-31'::date), '[)')
      && daterange(p_transfer_on, (p_transfer_on + 1), '[)');

  if target_capacity is not null and target_occupied >= target_capacity then
    raise exception 'TARGET_CLASS_CAPACITY_REACHED';
  end if;

  update public.class_placements
     set ends_on = p_transfer_on - 1,
         status = 'ENDED',
         reason = p_reason
   where id = current_placement_id;

  insert into public.class_placements (
    enrollment_id, class_group_id, starts_on, ends_on, status, reason
  )
  values (
    p_enrollment_id, p_target_class_group_id, p_transfer_on, null, 'ACTIVE', p_reason
  )
  returning id into new_placement_id;

  update public.student_course_participations scp
     set ends_on = p_transfer_on - 1,
         status = 'ENDED'
   where scp.student_id = (
     select e.student_id from public.student_enrollments e where e.id = p_enrollment_id
   )
     and scp.status = 'ACTIVE'
     and scp.starts_on <= p_transfer_on
     and (scp.ends_on is null or scp.ends_on >= p_transfer_on);

  get diagnostics closed_participations = row_count;

  for offering in
    select co.id as course_offering_id
    from public.course_offerings co
    where co.class_group_id = p_target_class_group_id
      and co.status in ('OPEN','ACTIVE')
  loop
    insert into public.student_course_participations (
      student_id, course_offering_id, starts_on, status
    )
    select e.student_id, offering.course_offering_id, p_transfer_on, 'ACTIVE'
    from public.student_enrollments e
    where e.id = p_enrollment_id
      and not exists (
        select 1
        from public.student_course_participations scp
        where scp.student_id = e.student_id
          and scp.course_offering_id = offering.course_offering_id
          and scp.status = 'ACTIVE'
      )
    on conflict do nothing;

    created_participations := created_participations + 1;
  end loop;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, reason, before_data, after_data
  )
  values (
    school_id, actor, 'TRANSFER_STUDENT_CLASS', 'class_placement', new_placement_id, p_reason,
    jsonb_build_object('previous_class_group_id', current_class_id, 'previous_placement_id', current_placement_id),
    jsonb_build_object(
      'target_class_group_id', p_target_class_group_id,
      'transfer_on', p_transfer_on,
      'closed_course_participations', closed_participations,
      'created_course_participations', created_participations
    )
  );

  result := jsonb_build_object(
    'placement_id', new_placement_id,
    'previous_class_group_id', current_class_id,
    'target_class_group_id', p_target_class_group_id,
    'transfer_on', p_transfer_on,
    'closed_course_participations', closed_participations,
    'created_course_participations', created_participations
  );

  perform private.complete_command(
    'transfer_student_class', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function private.validate_course_offering_context() from public;

revoke all on function public.create_class_group(
  uuid, uuid, text, uuid, text, integer, text, text, text
) from public;
revoke all on function public.update_class_group(
  uuid, text, uuid, text, integer, text, text, text
) from public;
revoke all on function public.close_class_group(
  uuid, date, text, text, text
) from public;
revoke all on function public.generate_class_offerings(uuid, text, text) from public;
revoke all on function public.assign_teacher_to_offering(
  uuid, uuid, date, date, text, text
) from public;
revoke all on function public.transfer_student_class(
  uuid, uuid, date, text, text, text
) from public;

grant execute on function public.create_class_group(
  uuid, uuid, text, uuid, text, integer, text, text, text
) to authenticated;
grant execute on function public.update_class_group(
  uuid, text, uuid, text, integer, text, text, text
) to authenticated;
grant execute on function public.close_class_group(
  uuid, date, text, text, text
) to authenticated;
grant execute on function public.generate_class_offerings(uuid, text, text) to authenticated;
grant execute on function public.assign_teacher_to_offering(
  uuid, uuid, date, date, text, text
) to authenticated;
grant execute on function public.transfer_student_class(
  uuid, uuid, date, text, text, text
) to authenticated;

-- Direct mutations are closed for aggregates whose invariants are now command-owned.
revoke insert, update, delete on public.class_groups from authenticated;
revoke insert, update, delete on public.course_offerings from authenticated;
revoke insert, update, delete on public.teacher_assignments from authenticated;
revoke insert, update, delete on public.class_placements from authenticated;
revoke insert, update, delete on public.student_course_participations from authenticated;

grant select on public.class_groups to authenticated;
grant select on public.course_offerings to authenticated;
grant select on public.teacher_assignments to authenticated;
grant select on public.class_placements to authenticated;
grant select on public.student_course_participations to authenticated;

create policy academic_ops_class_groups_read
on public.class_groups
for select to authenticated
using (
  private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
  or private.has_permission('enrollment.read', school_id)
);

create policy academic_ops_course_offerings_read
on public.course_offerings
for select to authenticated
using (
  private.has_permission('operations.read', school_id)
  or private.has_permission('operations.manage', school_id)
  or private.has_permission('assessment.read', school_id)
);

create policy academic_ops_teacher_assignments_read
on public.teacher_assignments
for select to authenticated
using (
  exists (
    select 1
    from public.course_offerings co
    where co.id = teacher_assignments.course_offering_id
      and (
        private.has_permission('operations.read', co.school_id)
        or private.has_permission('operations.manage', co.school_id)
      )
  )
);

create policy academic_ops_class_placements_read
on public.class_placements
for select to authenticated
using (
  exists (
    select 1
    from public.class_groups cg
    where cg.id = class_placements.class_group_id
      and (
        private.has_permission('operations.read', cg.school_id)
        or private.has_permission('operations.manage', cg.school_id)
        or private.has_permission('enrollment.read', cg.school_id)
      )
  )
);

create policy academic_ops_student_course_participations_read
on public.student_course_participations
for select to authenticated
using (
  exists (
    select 1
    from public.course_offerings co
    where co.id = student_course_participations.course_offering_id
      and (
        private.has_permission('operations.read', co.school_id)
        or private.has_permission('operations.manage', co.school_id)
        or private.has_permission('assessment.read', co.school_id)
      )
  )
);

-- The privileged functions run with an empty search_path and every relation is
-- explicitly schema-qualified.
alter function public.create_class_group(
  uuid, uuid, text, uuid, text, integer, text, text, text
) set search_path = '';

alter function public.update_class_group(
  uuid, text, uuid, text, integer, text, text, text
) set search_path = '';

alter function public.close_class_group(
  uuid, date, text, text, text
) set search_path = '';

alter function public.generate_class_offerings(
  uuid, text, text
) set search_path = '';

alter function public.assign_teacher_to_offering(
  uuid, uuid, date, date, text, text
) set search_path = '';

alter function public.transfer_student_class(
  uuid, uuid, date, text, text, text
) set search_path = '';
