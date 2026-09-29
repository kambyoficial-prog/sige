-- SIGE 0042 — People, admissions and academic structure read model
--
-- F3/F4 vertical slice:
-- - secure student/teacher/guardian/enrollment read models
-- - atomic student registration
-- - atomic guardian creation/linking
-- - class-group directory projection
--
-- The application never writes people/students/guardians through generic CRUD.
-- Mutations are narrow commands with authorization, idempotency and audit.

create or replace function public.register_student(
  p_school_id uuid,
  p_school_number text,
  p_full_name text,
  p_first_name text default null,
  p_last_name text default null,
  p_gender text default null,
  p_birth_date date default null,
  p_national_id text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_admission_date date default current_date,
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
  person_id uuid;
  student_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_school_id is null or p_school_number is null or length(trim(p_school_number)) = 0 then
    raise exception 'INVALID_ARGUMENT';
  end if;
  if p_full_name is null or length(trim(p_full_name)) < 2 then
    raise exception 'INVALID_ARGUMENT';
  end if;
  if not (select private.has_permission('enrollment.manage', p_school_id)) then
    raise exception 'FORBIDDEN';
  end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  perform 1 from public.schools where id = p_school_id and active for share;
  if not found then raise exception 'SCHOOL_NOT_FOUND'; end if;

  command_state := private.begin_command(
    'register_student', p_school_id, p_idempotency_key, p_request_hash
  );

  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  if exists (
    select 1 from public.students
    where school_id = p_school_id and school_number = trim(p_school_number)
  ) then
    raise exception 'STUDENT_SCHOOL_NUMBER_ALREADY_EXISTS';
  end if;

  if p_national_id is not null and exists (
    select 1 from public.people
    where national_id = trim(p_national_id)
  ) then
    raise exception 'NATIONAL_ID_ALREADY_EXISTS';
  end if;

  insert into public.people (
    full_name, first_name, last_name, gender, birth_date,
    national_id, phone, email, address
  )
  values (
    trim(p_full_name), nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''),
    nullif(trim(p_gender), ''), p_birth_date, nullif(trim(p_national_id), ''),
    nullif(trim(p_phone), ''), nullif(trim(p_email), ''), nullif(trim(p_address), '')
  )
  returning id into person_id;

  insert into public.students (
    school_id, person_id, school_number, status, admission_date
  )
  values (
    p_school_id, person_id, trim(p_school_number), 'ACTIVE', p_admission_date
  )
  returning id into student_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    p_school_id, actor, 'REGISTER_STUDENT', 'student', student_id,
    jsonb_build_object(
      'student_id', student_id,
      'person_id', person_id,
      'school_number', trim(p_school_number),
      'admission_date', p_admission_date
    )
  );

  result := jsonb_build_object(
    'student_id', student_id,
    'person_id', person_id,
    'school_id', p_school_id,
    'school_number', trim(p_school_number),
    'status', 'ACTIVE'
  );

  perform private.complete_command(
    'register_student', p_school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

create or replace function public.create_guardian(
  p_school_id uuid,
  p_student_id uuid,
  p_full_name text,
  p_relationship text default null,
  p_occupation text default null,
  p_identity_number text default null,
  p_address text default null,
  p_phone text default null,
  p_gender text default null,
  p_birth_date date default null,
  p_national_id text default null,
  p_is_primary boolean default false,
  p_lives_with_student boolean default null,
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
  person_id uuid;
  guardian_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_full_name is null or length(trim(p_full_name)) < 2 then raise exception 'INVALID_ARGUMENT'; end if;
  if not (select private.has_permission('enrollment.manage', p_school_id)) then raise exception 'FORBIDDEN'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  perform 1
  from public.students
  where id = p_student_id and school_id = p_school_id
  for share;
  if not found then raise exception 'STUDENT_NOT_FOUND'; end if;

  command_state := private.begin_command(
    'create_guardian', p_school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  if p_identity_number is not null and exists (
    select 1 from public.guardians
    where school_id = p_school_id and identity_number = trim(p_identity_number)
  ) then
    raise exception 'GUARDIAN_IDENTITY_NUMBER_ALREADY_EXISTS';
  end if;

  insert into public.people (
    full_name, gender, birth_date, national_id, phone, address
  )
  values (
    trim(p_full_name), nullif(trim(p_gender), ''), p_birth_date,
    nullif(trim(p_national_id), ''), nullif(trim(p_phone), ''),
    nullif(trim(p_address), '')
  )
  returning id into person_id;

  insert into public.guardians (
    school_id, person_id, relationship, occupation, identity_number, address, phone
  )
  values (
    p_school_id, person_id, nullif(trim(p_relationship), ''),
    nullif(trim(p_occupation), ''), nullif(trim(p_identity_number), ''),
    nullif(trim(p_address), ''), nullif(trim(p_phone), '')
  )
  returning id into guardian_id;

  if p_is_primary then
    update public.student_guardians
       set is_primary = false
     where student_id = p_student_id;
  end if;

  insert into public.student_guardians (
    student_id, guardian_id, relationship, is_primary, lives_with_student
  )
  values (
    p_student_id, guardian_id, nullif(trim(p_relationship), ''),
    p_is_primary, p_lives_with_student
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    p_school_id, actor, 'CREATE_GUARDIAN', 'guardian', guardian_id,
    jsonb_build_object(
      'guardian_id', guardian_id,
      'student_id', p_student_id,
      'relationship', p_relationship,
      'is_primary', p_is_primary
    )
  );

  result := jsonb_build_object(
    'guardian_id', guardian_id,
    'person_id', person_id,
    'student_id', p_student_id
  );

  perform private.complete_command(
    'create_guardian', p_school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

-- The old people policy exposed the complete people table to every authenticated
-- user. People become visible only through an authorized school relationship.
drop policy if exists people_read on public.people;

create policy people_read on public.people
for select to authenticated
using (
  exists (
    select 1 from public.students s
    where s.person_id = people.id
      and (
        private.has_permission('enrollment.read', s.school_id)
        or private.has_permission('enrollment.manage', s.school_id)
      )
  )
  or exists (
    select 1 from public.guardians g
    where g.person_id = people.id
      and private.has_permission('enrollment.read', g.school_id)
  )
  or exists (
    select 1 from public.teachers t
    where t.person_id = people.id
      and (
        private.has_permission('operations.read', t.school_id)
        or private.has_permission('assessment.read', t.school_id)
      )
  )
  or exists (
    select 1 from public.staff_members sm
    where sm.person_id = people.id
      and private.has_permission('administration.manage', sm.school_id)
  )
  or exists (
    select 1 from public.app_accounts aa
    where aa.person_id = people.id
      and aa.auth_user_id = (select auth.uid())
  )
);

create or replace view public.student_directory
with (security_invoker = true)
as
select
  s.id,
  s.school_id,
  s.school_number,
  s.status,
  s.admission_date,
  p.full_name,
  p.first_name,
  p.last_name,
  p.gender,
  p.birth_date,
  p.phone,
  p.email,
  current_enrollment.id as enrollment_id,
  current_enrollment.academic_year_id,
  current_enrollment.grade_level_id,
  current_enrollment.enrollment_status,
  current_enrollment.enrolled_on,
  current_class.class_group_id,
  current_class.class_name,
  current_class.section_code
from public.students s
join public.people p on p.id = s.person_id
left join lateral (
  select
    e.id,
    e.academic_year_id,
    e.grade_level_id,
    e.status as enrollment_status,
    e.enrolled_on
  from public.student_enrollments e
  where e.student_id = s.id
    and e.status in ('PENDING','ACTIVE','TRANSFERRED_IN')
  order by e.enrolled_on desc, e.enrollment_sequence desc
  limit 1
) current_enrollment on true
left join lateral (
  select
    cp.class_group_id,
    coalesce(cg.name, cg.code, cg.id::text) as class_name,
    cg.section_code
  from public.class_placements cp
  join public.class_groups cg on cg.id = cp.class_group_id
  where cp.enrollment_id = current_enrollment.id
    and cp.status = 'ACTIVE'
  order by cp.starts_on desc
  limit 1
) current_class on true;

create or replace view public.student_profile
with (security_invoker = true)
as
select
  sd.*,
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', g.id,
        'full_name', gp.full_name,
        'relationship', sg.relationship,
        'occupation', g.occupation,
        'identity_number', g.identity_number,
        'address', g.address,
        'phone', g.phone,
        'is_primary', sg.is_primary,
        'lives_with_student', sg.lives_with_student
      )
      order by sg.is_primary desc, gp.full_name
    )
    from public.student_guardians sg
    join public.guardians g on g.id = sg.guardian_id
    join public.people gp on gp.id = g.person_id
    where sg.student_id = sd.id
  ), '[]'::jsonb) as guardians,
  coalesce((
    select jsonb_agg(
      jsonb_build_object('id', si.id, 'type', si.type, 'value', si.value)
      order by si.type
    )
    from public.student_identifiers si
    where si.student_id = sd.id
  ), '[]'::jsonb) as identifiers
from public.student_directory sd;

create or replace view public.enrollment_directory
with (security_invoker = true)
as
select
  e.id,
  s.school_id,
  e.student_id,
  s.school_number,
  p.full_name as student_name,
  e.academic_year_id,
  ay.label as academic_year_label,
  e.grade_level_id,
  gl.name as grade_level_name,
  e.status,
  e.entry_type,
  e.enrolled_on,
  e.exited_on,
  e.exit_reason,
  e.enrollment_sequence,
  cp.class_group_id,
  coalesce(cg.name, cg.code) as class_name
from public.student_enrollments e
join public.students s on s.id = e.student_id
join public.people p on p.id = s.person_id
join public.academic_years ay on ay.id = e.academic_year_id
join public.grade_levels gl on gl.id = e.grade_level_id
left join lateral (
  select cp.class_group_id
  from public.class_placements cp
  where cp.enrollment_id = e.id and cp.status = 'ACTIVE'
  order by cp.starts_on desc
  limit 1
) placement on true
left join public.class_groups cg on cg.id = placement.class_group_id;

create or replace view public.teacher_directory
with (security_invoker = true)
as
select
  t.id,
  t.school_id,
  t.employee_code,
  t.status,
  p.full_name,
  p.first_name,
  p.last_name,
  p.phone,
  p.email
from public.teachers t
join public.people p on p.id = t.person_id;

create or replace view public.guardian_directory
with (security_invoker = true)
as
select
  g.id,
  g.school_id,
  g.person_id,
  p.full_name,
  g.relationship,
  g.occupation,
  g.identity_number,
  g.address,
  g.phone,
  count(sg.student_id)::integer as student_count
from public.guardians g
join public.people p on p.id = g.person_id
left join public.student_guardians sg on sg.guardian_id = g.id
group by
  g.id, g.school_id, g.person_id, p.full_name, g.relationship,
  g.occupation, g.identity_number, g.address, g.phone;

create or replace view public.class_group_directory
with (security_invoker = true)
as
select
  cg.id,
  cg.school_id,
  cg.academic_year_id,
  ay.label as academic_year_label,
  cg.grade_level_id,
  gl.name as grade_level_name,
  ac.name as academic_cycle_name,
  el.name as education_level_name,
  cg.section_code,
  cg.name,
  cg.status,
  cg.shift,
  cg.capacity,
  coalesce((
    select count(*)::integer
    from public.class_placements cp
    where cp.class_group_id = cg.id and cp.status = 'ACTIVE'
  ), 0) as student_count,
  leadership.teacher_id as director_teacher_id,
  director_person.full_name as director_teacher_name
from public.class_groups cg
join public.academic_years ay on ay.id = cg.academic_year_id
join public.grade_levels gl on gl.id = cg.grade_level_id
join public.academic_cycles ac on ac.id = gl.academic_cycle_id
join public.education_levels el on el.id = ac.education_level_id
left join lateral (
  select cgl.teacher_id
  from public.class_group_leadership cgl
  where cgl.class_group_id = cg.id
    and cgl.active
    and (cgl.ends_on is null or cgl.ends_on >= current_date)
    and cgl.starts_on <= current_date
  order by cgl.starts_on desc
  limit 1
) leadership on true
left join public.teachers director_teacher on director_teacher.id = leadership.teacher_id
left join public.people director_person on director_person.id = director_teacher.person_id;

grant select on public.student_directory to authenticated;
grant select on public.student_profile to authenticated;
grant select on public.enrollment_directory to authenticated;
grant select on public.teacher_directory to authenticated;
grant select on public.guardian_directory to authenticated;
grant select on public.class_group_directory to authenticated;

revoke all on function public.register_student(uuid, text, text, text, text, text, date, text, text, text, text, date, text, text) from public;
revoke all on function public.create_guardian(uuid, uuid, text, text, text, text, text, text, text, date, text, boolean, boolean, text, text) from public;

grant execute on function public.register_student(uuid, text, text, text, text, text, date, text, text, text, text, date, text, text) to authenticated;
grant execute on function public.create_guardian(uuid, uuid, text, text, text, text, text, text, text, date, text, boolean, boolean, text, text) to authenticated;
