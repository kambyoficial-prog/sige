
-- F6 closeout: exam epochs, eligibility, review and cycle outcomes.

create table if not exists public.exam_sessions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  academic_year_id uuid not null references public.academic_years(id),
  grade_level_id uuid not null references public.grade_levels(id),
  epoch smallint not null check (epoch in (1,2)),
  starts_on date,
  ends_on date,
  status text not null default 'DRAFT' check (status in ('DRAFT','OPEN','CLOSED','CANCELLED')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  closed_at timestamptz,
  closed_by uuid references auth.users(id),
  unique (academic_year_id, grade_level_id, epoch)
);

create table if not exists public.exam_registrations (
  id uuid primary key default gen_random_uuid(),
  exam_session_id uuid not null references public.exam_sessions(id),
  student_id uuid not null references public.students(id),
  course_offering_id uuid not null references public.course_offerings(id),
  eligibility_status text not null default 'PENDING'
    check (eligibility_status in ('PENDING','ELIGIBLE','INELIGIBLE','AUTHORIZED_ABSENCE','FRAUD_BLOCKED')),
  eligibility_reason text,
  registered_at timestamptz not null default now(),
  registered_by uuid references auth.users(id),
  unique (exam_session_id, student_id, course_offering_id)
);

alter table public.assessment_results
  add column if not exists exam_registration_id uuid references public.exam_registrations(id);

alter table public.assessment_results
  add column if not exists supersedes_assessment_result_id uuid references public.assessment_results(id);

create table if not exists public.exam_reviews (
  id uuid primary key default gen_random_uuid(),
  assessment_result_id uuid not null references public.assessment_results(id),
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz not null default now(),
  status text not null default 'REQUESTED'
    check (status in ('REQUESTED','UNDER_REVIEW','DECIDED','REJECTED','WITHDRAWN')),
  reason text not null,
  decision text,
  reviewed_score numeric,
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  report text
);

create table if not exists public.cycle_outcomes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  academic_year_id uuid not null references public.academic_years(id),
  student_id uuid not null references public.students(id),
  grade_level_id uuid not null references public.grade_levels(id),
  status text not null check (status in ('APPROVED','FAILED','INCOMPLETE')),
  global_average numeric(8,4),
  display_global_average numeric(8,2),
  rule_version text not null,
  input_snapshot jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  calculated_by uuid references auth.users(id),
  supersedes_outcome_id uuid references public.cycle_outcomes(id)
);

create index if not exists exam_registrations_student_idx
  on public.exam_registrations(student_id, exam_session_id);
create index if not exists exam_registrations_course_idx
  on public.exam_registrations(course_offering_id, exam_session_id);
create index if not exists exam_reviews_result_idx
  on public.exam_reviews(assessment_result_id, status);
create index if not exists cycle_outcomes_student_year_idx
  on public.cycle_outcomes(student_id, academic_year_id, grade_level_id, calculated_at desc);

alter table public.exam_sessions enable row level security;
alter table public.exam_registrations enable row level security;
alter table public.exam_reviews enable row level security;
alter table public.cycle_outcomes enable row level security;

create or replace function private.classify_grade(p_rule jsonb, p_value numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (
      select coalesce(x->>'code', x->>'label')
      from jsonb_array_elements(coalesce(p_rule->'scale','[]'::jsonb)) x
      where round(p_value) between (x->>'min')::numeric and (x->>'max')::numeric
      limit 1
    ),
    case when round(p_value) >= 10 then 'SATISFATORIO' else 'NAO_SATISFATORIO' end
  );
$$;

create or replace function public.register_exam_candidate(
  p_exam_session_id uuid,
  p_student_id uuid,
  p_course_offering_id uuid,
  p_eligibility_status text,
  p_reason text,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  school_id uuid;
  year_id uuid;
  grade_id uuid;
  epoch smallint;
  registration_id uuid;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select es.school_id, es.academic_year_id, es.grade_level_id, es.epoch
    into school_id, year_id, grade_id, epoch
  from public.exam_sessions es where es.id = p_exam_session_id for share;
  if school_id is null then raise exception 'EXAM_SESSION_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage', school_id) then raise exception 'FORBIDDEN'; end if;

  if not exists (
    select 1 from public.course_offerings co
    where co.id = p_course_offering_id
      and co.school_id = school_id
      and co.academic_year_id = year_id
  ) then raise exception 'COURSE_OFFERING_NOT_IN_EXAM_YEAR'; end if;

  command_state := private.begin_command('register_exam_candidate', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  insert into public.exam_registrations(
    exam_session_id, student_id, course_offering_id,
    eligibility_status, eligibility_reason, registered_by
  )
  values (
    p_exam_session_id, p_student_id, p_course_offering_id,
    p_eligibility_status, p_reason, actor
  )
  on conflict (exam_session_id, student_id, course_offering_id)
  do update set
    eligibility_status = excluded.eligibility_status,
    eligibility_reason = excluded.eligibility_reason,
    registered_by = excluded.registered_by,
    registered_at = now()
  returning id into registration_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'REGISTER_EXAM_CANDIDATE','exam_registration',registration_id,
         jsonb_build_object('session_id',p_exam_session_id,'student_id',p_student_id,
                            'course_offering_id',p_course_offering_id,'epoch',epoch,
                            'status',p_eligibility_status,'reason',p_reason));

  result := jsonb_build_object('exam_registration_id',registration_id,'status',p_eligibility_status);
  perform private.complete_command('register_exam_candidate',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.register_exam_candidate(uuid,uuid,uuid,text,text,text,text) from public;
grant execute on function public.register_exam_candidate(uuid,uuid,uuid,text,text,text,text) to authenticated;

create or replace function public.calculate_final_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_frequency_result_id uuid,
  p_exam_assessment_result_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  school_id uuid;
  academic_year_id uuid;
  grade_code text;
  parallelism boolean;
  rule_id uuid;
  rule_code text;
  rule_definition jsonb;
  terminal boolean;
  nd numeric(8,4);
  ne numeric(8,4);
  nf numeric(8,4);
  exam_status public.assessment_result_status;
  exam_epoch smallint;
  exam_registration_status text;
  result_id uuid;
  old_result_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id, gl.code, s.pedagogical_parallelism
    into school_id, academic_year_id, grade_code, parallelism
  from public.course_offerings co
  join public.class_groups cg on cg.id = co.class_group_id
  join public.grade_levels gl on gl.id = cg.grade_level_id
  join public.schools s on s.id = co.school_id
  where co.id = p_course_offering_id for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  select ay.grade_rule_version_id, gr.code, gr.definition
    into rule_id, rule_code, rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id
  where ay.id=academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  select exists (
    select 1 from jsonb_array_elements_text(coalesce(rule_definition#>'{examination,terminal_classes}','[]'::jsonb)) x
    where x = grade_code
       or x::text = to_jsonb(grade_code)::text
  ) into terminal;
  if not terminal then raise exception 'FINAL_EXAM_NOT_ALLOWED_FOR_GRADE'; end if;
  if parallelism is null then raise exception 'PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select ar.value into nd
  from public.academic_results ar
  where ar.id=p_frequency_result_id and ar.student_id=p_student_id
    and ar.course_offering_id=p_course_offering_id
    and ar.academic_year_id=academic_year_id
    and ar.result_type='FREQUENCY' and ar.status='PUBLISHED';
  if nd is null then raise exception 'PUBLISHED_FREQUENCY_RESULT_REQUIRED'; end if;

  select ar.status, er.eligibility_status, es.epoch
    into exam_status, exam_registration_status, exam_epoch
  from public.assessment_results ar
  join public.assessments a on a.id=ar.assessment_id
  left join public.exam_registrations er on er.id=ar.exam_registration_id
  left join public.exam_sessions es on es.id=er.exam_session_id
  where ar.id=p_exam_assessment_result_id
    and ar.student_id=p_student_id
    and a.course_offering_id=p_course_offering_id
    and a.type='EXAM';

  if exam_status is null then raise exception 'EXAM_RESULT_NOT_FOUND'; end if;
  if exam_status <> 'PUBLISHED' then raise exception 'PUBLISHED_EXAM_RESULT_REQUIRED'; end if;
  if exam_registration_status not in ('ELIGIBLE','AUTHORIZED_ABSENCE') then
    raise exception 'EXAM_REGISTRATION_NOT_ELIGIBLE';
  end if;

  select ar.normalized_score into ne
  from public.assessment_results ar where ar.id=p_exam_assessment_result_id;
  if ne is null then raise exception 'EXAM_SCORE_REQUIRED'; end if;

  command_state:=private.begin_command('calculate_final_result',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  if not parallelism then
    nf := (nd + ne)/2;
  elsif grade_code = '10' then
    nf := (3*nd + ne)/4;
  elsif grade_code = '12' then
    nf := (2*nd + ne)/3;
  else
    raise exception 'FINAL_FORMULA_NOT_CONFIGURED';
  end if;

  snapshot:=jsonb_build_object(
    'rule_version_id',rule_id,'rule_version',rule_code,'grade_code',grade_code,
    'pedagogical_parallelism',parallelism,'exam_epoch',exam_epoch,
    'frequency_result_id',p_frequency_result_id,
    'exam_assessment_result_id',p_exam_assessment_result_id,'nd',nd,'ne',ne,'nf',nf,
    'formula',case when not parallelism then '(NCD + NE) / 2'
      when grade_code='10' then '(3 * NCD + NE) / 4'
      else '(2 * NCD + NE) / 3' end
  );

  if exists(select 1 from public.academic_results where student_id=p_student_id
      and course_offering_id=p_course_offering_id and result_type='FINAL' and status='PUBLISHED')
    then raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION'; end if;

  select id into old_result_id from public.academic_results
  where student_id=p_student_id and course_offering_id=p_course_offering_id
    and result_type='FINAL' and status in ('CALCULATED','HOMOLOGATED')
  order by calculated_at desc limit 1 for update;
  if old_result_id is not null then update public.academic_results set status='SUPERSEDED' where id=old_result_id; end if;

  insert into public.academic_results(
    school_id,academic_year_id,student_id,course_offering_id,result_type,status,rule_version,
    value,display_value,classification,input_snapshot,calculated_by,supersedes_result_id
  )
  values(
    school_id,academic_year_id,p_student_id,p_course_offering_id,'FINAL','CALCULATED',rule_code,
    nf,round(nf),private.classify_grade(rule_definition,nf),snapshot,actor,old_result_id
  ) returning id into result_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CALCULATE_FINAL_RESULT','academic_result',result_id,snapshot);

  result:=jsonb_build_object('academic_result_id',result_id,'result_type','FINAL',
    'status','CALCULATED','value',nf,'display_value',round(nf),'rule_version',rule_code);
  perform private.complete_command('calculate_final_result',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) to authenticated;

create or replace function public.calculate_cycle_outcome(
  p_student_id uuid,
  p_academic_year_id uuid,
  p_grade_level_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  grade_code text;
  rule_id uuid;
  rule_code text;
  rule_definition jsonb;
  global_average numeric(8,4);
  result_count integer;
  failed_count integer;
  exam_below_min integer;
  min_exam numeric;
  approved boolean;
  outcome_id uuid;
  old_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select s.id,gl.code into school_id,grade_code
  from public.schools s
  join public.academic_years ay on ay.school_id=s.id
  join public.grade_levels gl on gl.id=p_grade_level_id
  where ay.id=p_academic_year_id;
  if school_id is null then raise exception 'ACADEMIC_CONTEXT_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select ay.grade_rule_version_id,gr.code,gr.definition into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id
  where ay.id=p_academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  select count(*),avg(ar.value),count(*) filter(where round(ar.value)<10)
    into result_count,global_average,failed_count
  from public.academic_results ar
  join public.course_offerings co on co.id=ar.course_offering_id
  join public.class_groups cg on cg.id=co.class_group_id
  where ar.student_id=p_student_id and ar.academic_year_id=p_academic_year_id
    and ar.result_type='FINAL' and ar.status='PUBLISHED'
    and cg.grade_level_id=p_grade_level_id;

  if result_count=0 or global_average is null then raise exception 'FINAL_RESULTS_INCOMPLETE'; end if;

  min_exam:=case when grade_code='10' then 8 else 9 end;

  select count(*) into exam_below_min
  from public.assessment_results ar
  join public.assessments a on a.id=ar.assessment_id
  join public.course_offerings co on co.id=a.course_offering_id
  join public.class_groups cg on cg.id=co.class_group_id
  where ar.student_id=p_student_id and co.academic_year_id=p_academic_year_id
    and cg.grade_level_id=p_grade_level_id and a.type='EXAM'
    and ar.status='PUBLISHED' and ar.normalized_score < min_exam;

  approved:=round(global_average)>=10 and failed_count=0 and exam_below_min=0;

  command_state:=private.begin_command('calculate_cycle_outcome',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  select id into old_id from public.cycle_outcomes
  where student_id=p_student_id and academic_year_id=p_academic_year_id and grade_level_id=p_grade_level_id
  order by calculated_at desc limit 1 for update;
  if old_id is not null then
    update public.cycle_outcomes set status='INCOMPLETE' where id=old_id;
  end if;

  snapshot:=jsonb_build_object(
    'rule_version_id',rule_id,'rule_version',rule_code,'grade_code',grade_code,
    'global_average',global_average,'final_result_count',result_count,
    'failed_final_results',failed_count,'exam_minimum',min_exam,
    'exam_below_minimum',exam_below_min
  );

  insert into public.cycle_outcomes(
    school_id,academic_year_id,student_id,grade_level_id,status,
    global_average,display_global_average,rule_version,input_snapshot,calculated_by,supersedes_outcome_id
  )
  values(school_id,p_academic_year_id,p_student_id,p_grade_level_id,
    case when approved then 'APPROVED' else 'FAILED' end,
    global_average,round(global_average),rule_code,snapshot,actor,old_id)
  returning id into outcome_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CALCULATE_CYCLE_OUTCOME','cycle_outcome',outcome_id,snapshot);

  result:=jsonb_build_object('cycle_outcome_id',outcome_id,
    'status',case when approved then 'APPROVED' else 'FAILED' end,
    'global_average',global_average,'display_global_average',round(global_average));
  perform private.complete_command('calculate_cycle_outcome',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_cycle_outcome(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_cycle_outcome(uuid,uuid,uuid,text,text) to authenticated;

-- Exam read models
drop view if exists public.exam_candidate_directory;
create view public.exam_candidate_directory
with (security_invoker=true)
as
select
  er.id as exam_registration_id,
  es.id as exam_session_id,
  es.academic_year_id,
  es.epoch,
  es.status as session_status,
  er.student_id,
  s.school_number as student_number,
  p.full_name as student_name,
  er.course_offering_id,
  sub.code as subject_code,
  sub.name as subject_name,
  er.eligibility_status,
  er.eligibility_reason,
  er.registered_at
from public.exam_registrations er
join public.exam_sessions es on es.id=er.exam_session_id
join public.students s on s.id=er.student_id
join public.people p on p.id=s.person_id
join public.course_offerings co on co.id=er.course_offering_id
join public.subjects sub on sub.id=co.subject_id;

grant select on public.exam_candidate_directory to authenticated;

drop view if exists public.cycle_outcome_directory;
create view public.cycle_outcome_directory
with (security_invoker=true)
as
select
  co.id as cycle_outcome_id,
  co.school_id,co.academic_year_id,co.student_id,
  s.school_number as student_number,p.full_name as student_name,
  co.grade_level_id,gl.code as grade_code,gl.name as grade_name,
  co.status,co.global_average,co.display_global_average,
  co.rule_version,co.calculated_at
from public.cycle_outcomes co
join public.students s on s.id=co.student_id
join public.people p on p.id=s.person_id
join public.grade_levels gl on gl.id=co.grade_level_id;

grant select on public.cycle_outcome_directory to authenticated;

-- Direct writes remain closed; commands are the mutation boundary.
revoke insert,update,delete on public.exam_sessions from authenticated;
revoke insert,update,delete on public.exam_registrations from authenticated;
revoke insert,update,delete on public.exam_reviews from authenticated;
revoke insert,update,delete on public.cycle_outcomes from authenticated;
revoke insert,update,delete on public.assessment_results from authenticated;
