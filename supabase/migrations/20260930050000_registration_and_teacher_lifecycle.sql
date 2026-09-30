-- SIGE administrative lifecycle: explicit registration + teacher intake without institutional email.
create table if not exists public.student_registrations (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id) on delete restrict,
 enrollment_id uuid not null references public.student_enrollments(id) on delete restrict,
 academic_year_id uuid not null references public.academic_years(id) on delete restrict,
 registration_type text not null default 'INITIAL', status text not null default 'CONFIRMED',
 registered_on date not null default current_date, confirmed_on date, cancelled_on date, cancel_reason text,
 previous_registration_id uuid references public.student_registrations(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint student_registrations_type_ck check (registration_type in ('INITIAL','RENEWAL','TRANSFER_IN','REENTRY')),
 constraint student_registrations_status_ck check (status in ('DRAFT','PENDING','CONFIRMED','CANCELLED','WITHDRAWN','TRANSFERRED')),
 constraint student_registrations_dates_ck check (cancelled_on is null or cancelled_on >= registered_on),
 unique (student_id, academic_year_id)
);
create index if not exists student_registrations_year_status_idx on public.student_registrations (academic_year_id,status);
alter table public.student_registrations enable row level security;
drop policy if exists student_registrations_read on public.student_registrations;
create policy student_registrations_read on public.student_registrations for select to authenticated using (
 exists (select 1 from public.students s where s.id=student_registrations.student_id and private.has_permission('enrollment.read',s.school_id))
);
create or replace function public.create_student_registration(p_student_id uuid,p_academic_year_id uuid,p_registration_type text,p_registered_on date default current_date,p_idempotency_key text default null,p_request_hash text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; year_school uuid; year_status public.academic_year_status; enrollment_id uuid; previous_id uuid; registration_id uuid; result jsonb; command_state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 if p_registration_type not in ('INITIAL','RENEWAL','TRANSFER_IN','REENTRY') then raise exception 'INVALID_REGISTRATION_TYPE'; end if;
 select s.school_id into school_id from public.students s where s.id=p_student_id for update;
 if school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
 select ay.school_id,ay.status into year_school,year_status from public.academic_years ay where ay.id=p_academic_year_id for share;
 if year_school is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
 if year_school<>school_id then raise exception 'SCHOOL_CONTEXT_MISMATCH'; end if;
 if year_status<>'OPEN' then raise exception 'ACADEMIC_YEAR_NOT_OPEN'; end if;
 if not private.has_permission('enrollment.manage',school_id) then raise exception 'FORBIDDEN'; end if;
 select e.id into enrollment_id from public.student_enrollments e where e.student_id=p_student_id and e.academic_year_id=p_academic_year_id and e.status in ('PENDING','ACTIVE','TRANSFERRED_IN') order by e.enrollment_sequence desc limit 1;
 if enrollment_id is null then raise exception 'ENROLLMENT_REQUIRED_BEFORE_REGISTRATION'; end if;
 if p_registration_type='RENEWAL' then
   select r.id into previous_id from public.student_registrations r where r.student_id=p_student_id and r.academic_year_id<p_academic_year_id and r.status in ('CONFIRMED','COMPLETED') order by r.registered_on desc limit 1;
 end if;
 if exists(select 1 from public.student_registrations r where r.student_id=p_student_id and r.academic_year_id=p_academic_year_id) then raise exception 'REGISTRATION_ALREADY_EXISTS'; end if;
 command_state:=private.begin_command('create_student_registration',school_id,p_idempotency_key,p_request_hash);
 if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
 insert into public.student_registrations(student_id,enrollment_id,academic_year_id,registration_type,status,registered_on,confirmed_on,previous_registration_id)
 values(p_student_id,enrollment_id,p_academic_year_id,p_registration_type,'CONFIRMED',p_registered_on,now(),previous_id) returning id into registration_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
 values(school_id,actor,'CREATE_STUDENT_REGISTRATION','student_registration',registration_id,jsonb_build_object('student_id',p_student_id,'enrollment_id',enrollment_id,'academic_year_id',p_academic_year_id,'registration_type',p_registration_type,'previous_registration_id',previous_id));
 result:=jsonb_build_object('registration_id',registration_id,'enrollment_id',enrollment_id,'registration_type',p_registration_type,'status','CONFIRMED');
 perform private.complete_command('create_student_registration',school_id,p_idempotency_key,result); return result;
end; $$;
revoke all on function public.create_student_registration(uuid,uuid,text,date,text,text) from public;
grant execute on function public.create_student_registration(uuid,uuid,text,date,text,text) to authenticated;
create or replace view public.registration_directory with(security_invoker=true) as
select r.id,r.student_id,r.enrollment_id,r.academic_year_id,ay.label academic_year,s.school_number,pe.full_name student_name,gl.code grade_code,gl.name grade_name,r.registration_type,r.status,r.registered_on,r.confirmed_on,r.previous_registration_id
from public.student_registrations r join public.students s on s.id=r.student_id join public.people pe on pe.id=s.person_id join public.academic_years ay on ay.id=r.academic_year_id join public.student_enrollments e on e.id=r.enrollment_id join public.grade_levels gl on gl.id=e.grade_level_id;
grant select on public.registration_directory to authenticated;
create or replace function public.create_teacher(p_school_id uuid,p_employee_code text,p_full_name text,p_gender text default null,p_birth_date date default null,p_national_id text default null,p_phone text default null,p_address text default null,p_idempotency_key text default null,p_request_hash text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); person_id uuid; teacher_id uuid; result jsonb; command_state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 if not private.has_permission('teacher.manage',p_school_id) then raise exception 'FORBIDDEN'; end if;
 if nullif(trim(p_employee_code),'') is null then raise exception 'TEACHER_CODE_REQUIRED'; end if;
 if nullif(trim(p_full_name),'') is null then raise exception 'TEACHER_NAME_REQUIRED'; end if;
 if exists(select 1 from public.teachers where school_id=p_school_id and employee_code=trim(p_employee_code)) then raise exception 'TEACHER_CODE_ALREADY_EXISTS'; end if;
 command_state:=private.begin_command('create_teacher',p_school_id,p_idempotency_key,p_request_hash);
 if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
 insert into public.people(full_name,gender,birth_date,national_id,phone,address) values(trim(p_full_name),nullif(trim(p_gender),''),p_birth_date,nullif(trim(p_national_id),''),nullif(trim(p_phone),''),nullif(trim(p_address),'')) returning id into person_id;
 insert into public.teachers(school_id,person_id,employee_code,status) values(p_school_id,person_id,trim(p_employee_code),'ACTIVE') returning id into teacher_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data) values(p_school_id,actor,'CREATE_TEACHER','teacher',teacher_id,jsonb_build_object('teacher_id',teacher_id,'person_id',person_id,'employee_code',trim(p_employee_code)));
 result:=jsonb_build_object('teacher_id',teacher_id,'person_id',person_id,'employee_code',trim(p_employee_code));
 perform private.complete_command('create_teacher',p_school_id,p_idempotency_key,result); return result;
end; $$;
revoke all on function public.create_teacher(uuid,text,text,text,date,text,text,text,text,text) from public;
grant execute on function public.create_teacher(uuid,text,text,text,date,text,text,text,text,text) to authenticated;
