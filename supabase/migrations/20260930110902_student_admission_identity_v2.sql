alter table public.student_identifiers
  alter column value drop not null;

create unique index if not exists student_identifiers_type_value_uq
  on public.student_identifiers (student_id, type, value)
  where value is not null;

create or replace function private.next_student_school_number(p_school_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_number integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text, 0));
  select coalesce(max(nullif(school_number, '')::integer), 0) + 1 into next_number
  from public.students
  where school_id = p_school_id and school_number ~ '^[0-9]{1,6}$';
  if next_number > 999999 then raise exception 'STUDENT_SCHOOL_NUMBER_EXHAUSTED'; end if;
  return lpad(next_number::text, 6, '0');
end;
$$;

revoke all on function private.next_student_school_number(uuid) from public;
grant execute on function private.next_student_school_number(uuid) to authenticated;

drop function if exists public.register_student(uuid,text,text,text,text,text,date,text,text,text,text,date,text,text);

create function public.register_student(
  p_school_id uuid,
  p_first_name text,
  p_last_name text default null,
  p_gender text default null,
  p_birth_date date default null,
  p_document_type text default null,
  p_document_value text default null,
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
  school_number text;
  result jsonb;
  command_state jsonb;
  normalized_document text := nullif(trim(p_document_value), '');
  normalized_document_type text := nullif(trim(p_document_type), '');
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_school_id is null or p_first_name is null or length(trim(p_first_name)) < 2 then raise exception 'INVALID_ARGUMENT'; end if;
  if not (select private.has_permission('enrollment.manage', p_school_id)) then raise exception 'FORBIDDEN'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  perform 1 from public.schools where id = p_school_id and active;
  if not found then raise exception 'SCHOOL_NOT_FOUND'; end if;

  if normalized_document_type is not null and normalized_document is not null and exists (
    select 1 from public.student_identifiers si
    join public.students s on s.id = si.student_id
    where s.school_id = p_school_id and si.type = normalized_document_type and si.value = normalized_document
  ) then raise exception 'STUDENT_DOCUMENT_ALREADY_EXISTS'; end if;

  command_state := private.begin_command('register_student', p_school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  school_number := private.next_student_school_number(p_school_id);

  insert into public.people (full_name, first_name, last_name, gender, birth_date, phone, email, address)
  values (
    trim(concat_ws(' ', nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''))),
    nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''), nullif(trim(p_gender), ''),
    p_birth_date, nullif(trim(p_phone), ''), nullif(trim(p_email), ''), nullif(trim(p_address), '')
  ) returning id into person_id;

  insert into public.students (school_id, person_id, school_number, status, admission_date)
  values (p_school_id, person_id, school_number, 'ACTIVE', p_admission_date)
  returning id into student_id;

  if normalized_document_type is not null then
    insert into public.student_identifiers (student_id, type, value)
    values (student_id, normalized_document_type, normalized_document);
  end if;

  insert into public.audit_events (school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values (
    p_school_id, actor, 'REGISTER_STUDENT', 'student', student_id,
    jsonb_build_object('student_id', student_id, 'person_id', person_id, 'school_number', school_number,
      'document_type', normalized_document_type, 'document_has_value', normalized_document is not null,
      'admission_date', p_admission_date)
  );

  result := jsonb_build_object('student_id', student_id, 'person_id', person_id, 'school_id', p_school_id,
    'school_number', school_number, 'status', 'ACTIVE');

  perform private.complete_command('register_student', p_school_id, p_idempotency_key, result);
  return result;
end;
$$;

revoke all on function public.register_student(uuid,text,text,text,date,text,text,text,text,text,date,text,text) from public;
grant execute on function public.register_student(uuid,text,text,text,date,text,text,text,text,text,date,text,text) to authenticated;
