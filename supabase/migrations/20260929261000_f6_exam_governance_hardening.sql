
-- F6 hardening: exam session lifecycle, second-epoch precedence and review workflow.

alter table public.assessments
  add column if not exists exam_session_id uuid references public.exam_sessions(id);

create index if not exists assessments_exam_session_idx
  on public.assessments(exam_session_id);

create or replace function public.create_exam_session(
  p_academic_year_id uuid,
  p_grade_level_id uuid,
  p_epoch smallint,
  p_starts_on date,
  p_ends_on date,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  session_id uuid;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_epoch not in (1,2) then raise exception 'INVALID_EXAM_EPOCH'; end if;
  select ay.school_id into school_id from public.academic_years ay where ay.id=p_academic_year_id for share;
  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;
  if p_ends_on < p_starts_on then raise exception 'INVALID_EXAM_DATES'; end if;

  command_state:=private.begin_command('create_exam_session',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  insert into public.exam_sessions(
    school_id,academic_year_id,grade_level_id,epoch,starts_on,ends_on,status,created_by
  ) values(school_id,p_academic_year_id,p_grade_level_id,p_epoch,p_starts_on,p_ends_on,'DRAFT',actor)
  returning id into session_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CREATE_EXAM_SESSION','exam_session',session_id,
    jsonb_build_object('academic_year_id',p_academic_year_id,'grade_level_id',p_grade_level_id,
      'epoch',p_epoch,'starts_on',p_starts_on,'ends_on',p_ends_on));

  result:=jsonb_build_object('exam_session_id',session_id,'status','DRAFT','epoch',p_epoch);
  perform private.complete_command('create_exam_session',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.create_exam_session(uuid,uuid,smallint,date,date,text,text) from public;
grant execute on function public.create_exam_session(uuid,uuid,smallint,date,date,text,text) to authenticated;

create or replace function public.set_exam_session_status(
  p_exam_session_id uuid,
  p_status text,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  current_status text;
  result jsonb;
  command_state jsonb;
begin
  select es.school_id,es.status into school_id,current_status
  from public.exam_sessions es where es.id=p_exam_session_id for update;
  if school_id is null then raise exception 'EXAM_SESSION_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  if p_status not in ('OPEN','CLOSED','CANCELLED') then raise exception 'INVALID_EXAM_SESSION_STATUS'; end if;
  if p_status='OPEN' and current_status <> 'DRAFT' then raise exception 'EXAM_SESSION_CANNOT_OPEN'; end if;
  if p_status='CLOSED' and current_status <> 'OPEN' then raise exception 'EXAM_SESSION_CANNOT_CLOSE'; end if;
  if p_status='CANCELLED' and current_status not in ('DRAFT','OPEN') then raise exception 'EXAM_SESSION_CANNOT_CANCEL'; end if;

  command_state:=private.begin_command('set_exam_session_status',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  update public.exam_sessions
  set status=p_status,
      closed_at=case when p_status='CLOSED' then now() else closed_at end,
      closed_by=case when p_status='CLOSED' then actor else closed_by end
  where id=p_exam_session_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'SET_EXAM_SESSION_STATUS','exam_session',p_exam_session_id,
    jsonb_build_object('from',current_status,'to',p_status));

  result:=jsonb_build_object('exam_session_id',p_exam_session_id,'status',p_status);
  perform private.complete_command('set_exam_session_status',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.set_exam_session_status(uuid,text,text,text) from public;
grant execute on function public.set_exam_session_status(uuid,text,text,text) to authenticated;

create or replace function public.request_exam_review(
  p_assessment_result_id uuid,
  p_reason text,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  review_id uuid;
  result_status public.assessment_result_status;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'REVIEW_REASON_REQUIRED'; end if;

  select co.school_id,ar.status into school_id,result_status
  from public.assessment_results ar
  join public.assessments a on a.id=ar.assessment_id
  join public.course_offerings co on co.id=a.course_offering_id
  where ar.id=p_assessment_result_id;
  if school_id is null then raise exception 'ASSESSMENT_RESULT_NOT_FOUND'; end if;
  if result_status <> 'PUBLISHED' then raise exception 'ONLY_PUBLISHED_RESULTS_CAN_BE_REVIEWED'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  command_state:=private.begin_command('request_exam_review',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  insert into public.exam_reviews(assessment_result_id,requested_by,reason)
  values(p_assessment_result_id,actor,p_reason) returning id into review_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'REQUEST_EXAM_REVIEW','exam_review',review_id,
    jsonb_build_object('assessment_result_id',p_assessment_result_id,'reason',p_reason));

  result:=jsonb_build_object('exam_review_id',review_id,'status','REQUESTED');
  perform private.complete_command('request_exam_review',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.request_exam_review(uuid,text,text,text) from public;
grant execute on function public.request_exam_review(uuid,text,text,text) to authenticated;

create or replace function public.decide_exam_review(
  p_exam_review_id uuid,
  p_decision text,
  p_reviewed_score numeric,
  p_report text,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  result_id uuid;
  review_status text;
  result jsonb;
  command_state jsonb;
begin
  select co.school_id,er.status,er.assessment_result_id
    into school_id,review_status,result_id
  from public.exam_reviews er
  join public.assessment_results ar on ar.id=er.assessment_result_id
  join public.assessments a on a.id=ar.assessment_id
  join public.course_offerings co on co.id=a.course_offering_id
  where er.id=p_exam_review_id for update;
  if school_id is null then raise exception 'EXAM_REVIEW_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;
  if review_status not in ('REQUESTED','UNDER_REVIEW') then raise exception 'EXAM_REVIEW_NOT_OPEN'; end if;
  if p_decision not in ('UPHELD','CHANGED') then raise exception 'INVALID_REVIEW_DECISION'; end if;
  if p_decision='CHANGED' and (p_reviewed_score is null or p_reviewed_score<0 or p_reviewed_score>20) then
    raise exception 'INVALID_REVIEWED_SCORE';
  end if;

  command_state:=private.begin_command('decide_exam_review',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  update public.exam_reviews
  set status='DECIDED',decision=p_decision,reviewed_score=p_reviewed_score,
      report=p_report,decided_by=actor,decided_at=now()
  where id=p_exam_review_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'DECIDE_EXAM_REVIEW','exam_review',p_exam_review_id,
    jsonb_build_object('decision',p_decision,'reviewed_score',p_reviewed_score,'report',p_report));

  result:=jsonb_build_object('exam_review_id',p_exam_review_id,'status','DECIDED','decision',p_decision);
  perform private.complete_command('decide_exam_review',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.decide_exam_review(uuid,text,numeric,text,text,text) from public;
grant execute on function public.decide_exam_review(uuid,text,numeric,text,text,text) to authenticated;

-- A second-epoch published exam supersedes first-epoch exam as the source for final calculation.
create or replace function public.calculate_final_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_frequency_result_id uuid,
  p_exam_assessment_result_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
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
  second_epoch_published boolean;
  result_id uuid;
  old_result_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id,co.academic_year_id,gl.code,s.pedagogical_parallelism
    into school_id,academic_year_id,grade_code,parallelism
  from public.course_offerings co
  join public.class_groups cg on cg.id=co.class_group_id
  join public.grade_levels gl on gl.id=cg.grade_level_id
  join public.schools s on s.id=co.school_id
  where co.id=p_course_offering_id for share;
  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ay.grade_rule_version_id,gr.code,gr.definition
    into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id
  where ay.id=academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  select exists(
    select 1 from jsonb_array_elements_text(coalesce(rule_definition#>'{examination,terminal_classes}','[]'::jsonb)) x
    where x=grade_code
  ) into terminal;
  if not terminal then raise exception 'FINAL_EXAM_NOT_ALLOWED_FOR_GRADE'; end if;
  if parallelism is null then raise exception 'PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select ar.value into nd from public.academic_results ar
  where ar.id=p_frequency_result_id and ar.student_id=p_student_id
    and ar.course_offering_id=p_course_offering_id and ar.academic_year_id=academic_year_id
    and ar.result_type='FREQUENCY' and ar.status='PUBLISHED';
  if nd is null then raise exception 'PUBLISHED_FREQUENCY_RESULT_REQUIRED'; end if;

  select ar.status,er.eligibility_status,es.epoch
    into exam_status,exam_registration_status,exam_epoch
  from public.assessment_results ar
  join public.assessments a on a.id=ar.assessment_id
  left join public.exam_registrations er on er.id=ar.exam_registration_id
  left join public.exam_sessions es on es.id=er.exam_session_id
  where ar.id=p_exam_assessment_result_id and ar.student_id=p_student_id
    and a.course_offering_id=p_course_offering_id and a.type='EXAM';
  if exam_status is null then raise exception 'EXAM_RESULT_NOT_FOUND'; end if;
  if exam_status<>'PUBLISHED' then raise exception 'PUBLISHED_EXAM_RESULT_REQUIRED'; end if;
  if exam_registration_status<>'ELIGIBLE' then raise exception 'EXAM_REGISTRATION_NOT_ELIGIBLE'; end if;

  select exists(
    select 1
    from public.assessment_results ar2
    join public.assessments a2 on a2.id=ar2.assessment_id
    join public.exam_registrations er2 on er2.id=ar2.exam_registration_id
    join public.exam_sessions es2 on es2.id=er2.exam_session_id
    where ar2.student_id=p_student_id and a2.course_offering_id=p_course_offering_id
      and a2.type='EXAM' and ar2.status='PUBLISHED' and es2.epoch=2
  ) into second_epoch_published;
  if exam_epoch=1 and second_epoch_published then raise exception 'FIRST_EPOCH_SUPERSEDED_BY_SECOND_EPOCH'; end if;

  select ar.normalized_score into ne from public.assessment_results ar where ar.id=p_exam_assessment_result_id;
  if ne is null then raise exception 'EXAM_SCORE_REQUIRED'; end if;

  command_state:=private.begin_command('calculate_final_result',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  if not parallelism then
    nf:=(nd+ne)/2;
  elsif grade_code='10' then
    nf:=(3*nd+ne)/4;
  elsif grade_code='12' then
    nf:=(2*nd+ne)/3;
  else
    raise exception 'FINAL_FORMULA_NOT_CONFIGURED';
  end if;

  snapshot:=jsonb_build_object(
    'rule_version_id',rule_id,'rule_version',rule_code,'grade_code',grade_code,
    'pedagogical_parallelism',parallelism,'exam_epoch',exam_epoch,
    'frequency_result_id',p_frequency_result_id,'exam_assessment_result_id',p_exam_assessment_result_id,
    'nd',nd,'ne',ne,'nf',nf,
    'formula',case when not parallelism then '(NCD + NE) / 2'
      when grade_code='10' then '(3 * NCD + NE) / 4' else '(2 * NCD + NE) / 3' end
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

  result:=jsonb_build_object('academic_result_id',result_id,'result_type','FINAL','status','CALCULATED',
    'value',nf,'display_value',round(nf),'rule_version',rule_code);
  perform private.complete_command('calculate_final_result',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) to authenticated;
