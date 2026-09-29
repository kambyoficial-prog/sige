
update public.grade_rule_versions
set definition = definition
  || jsonb_build_object(
    'trimester_formula', jsonb_build_object('macs_weight',2,'at_weight',1,'divisor',3),
    'frequency_formula', jsonb_build_object('trimester_weight',1,'divisor',3),
    'final_coefficients', jsonb_build_object(
      'with_parallelism', jsonb_build_object(
        '10', jsonb_build_object('ncd_weight',3,'exam_weight',1,'divisor',4),
        '12', jsonb_build_object('ncd_weight',2,'exam_weight',1,'divisor',3)
      ),
      'without_parallelism', jsonb_build_object('ncd_weight',1,'exam_weight',1,'divisor',2)
    )
  )
where code='MZ-ESG-RGA-2019';

create or replace function public.calculate_trimester_result(
  p_course_offering_id uuid,p_student_id uuid,p_assessment_period_id uuid,
  p_idempotency_key text,p_request_hash text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid(); school_id uuid; academic_year_id uuid; period_year uuid;
  rule_id uuid; rule_code text; rule_definition jsonb; participant boolean;
  acs_count integer; at_count integer; acs_min integer; at_min integer; at_max integer;
  macs numeric(8,4); at_value numeric(8,4); mt numeric(8,4);
  macs_weight numeric; at_weight numeric; formula_divisor numeric;
  result_id uuid; old_result_id uuid; snapshot jsonb; command_state jsonb; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select co.school_id,co.academic_year_id into school_id,academic_year_id from public.course_offerings co where co.id=p_course_offering_id for share;
  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  select ap.academic_year_id into period_year from public.assessment_periods ap where ap.id=p_assessment_period_id for share;
  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if period_year<>academic_year_id then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;
  select ay.grade_rule_version_id,gr.code,gr.definition into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id where ay.id=academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  acs_min:=coalesce((rule_definition#>>'{trimester,required,0,minimum_count}')::integer,2);
  at_min:=coalesce((rule_definition#>>'{trimester,required,1,minimum_count}')::integer,1);
  at_max:=nullif((rule_definition#>>'{trimester,required,1,maximum_count}')::integer,0);
  macs_weight:=nullif((rule_definition#>>'{trimester_formula,macs_weight}')::numeric,0);
  at_weight:=nullif((rule_definition#>>'{trimester_formula,at_weight}')::numeric,0);
  formula_divisor:=nullif((rule_definition#>>'{trimester_formula,divisor}')::numeric,0);
  if macs_weight is null or at_weight is null or formula_divisor is null then raise exception 'TRIMESTER_FORMULA_NOT_CONFIGURED'; end if;

  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;
  select exists(
    select 1 from public.student_course_participations scp join public.assessment_periods ap on ap.id=p_assessment_period_id
    where scp.student_id=p_student_id and scp.course_offering_id=p_course_offering_id
      and scp.starts_on<=coalesce(ap.ends_on,'9999-12-31'::date)
      and (scp.ends_on is null or scp.ends_on>=coalesce(ap.starts_on,scp.starts_on))
      and scp.status in ('ACTIVE','ENDED')
  ) into participant;
  if not participant then raise exception 'STUDENT_NOT_COURSE_PARTICIPANT'; end if;

  command_state:=private.begin_command('calculate_trimester_result',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  select count(*) filter(where a.type='ACS' and ar.status='PUBLISHED' and ar.normalized_score is not null),
         avg(ar.normalized_score) filter(where a.type='ACS' and ar.status='PUBLISHED' and ar.normalized_score is not null),
         count(*) filter(where a.type='AT' and ar.status='PUBLISHED' and ar.normalized_score is not null),
         max(ar.normalized_score) filter(where a.type='AT' and ar.status='PUBLISHED' and ar.normalized_score is not null)
    into acs_count,macs,at_count,at_value
  from public.assessments a join public.assessment_results ar on ar.assessment_id=a.id
  where a.course_offering_id=p_course_offering_id and a.assessment_period_id=p_assessment_period_id and ar.student_id=p_student_id;

  if acs_count<acs_min then raise exception 'TRIMESTER_ACS_INCOMPLETE'; end if;
  if at_count<at_min or (at_max is not null and at_count>at_max) then raise exception 'TRIMESTER_AT_INVALID'; end if;
  mt:=(macs_weight*macs+at_weight*at_value)/formula_divisor;

  snapshot:=jsonb_build_object('rule_version_id',rule_id,'rule_version',rule_code,'assessment_period_id',p_assessment_period_id,
    'course_offering_id',p_course_offering_id,'student_id',p_student_id,'acs_count',acs_count,'macs',macs,'at',at_value,'mt',mt,
    'formula',rule_definition->'trimester_formula');

  if exists(select 1 from public.academic_results where student_id=p_student_id and course_offering_id=p_course_offering_id
      and assessment_period_id=p_assessment_period_id and result_type='TRIMESTER' and status='PUBLISHED')
    then raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION'; end if;

  select id into old_result_id from public.academic_results where student_id=p_student_id and course_offering_id=p_course_offering_id
    and assessment_period_id=p_assessment_period_id and result_type='TRIMESTER' and status in ('CALCULATED','HOMOLOGATED')
    order by calculated_at desc limit 1 for update;
  if old_result_id is not null then update public.academic_results set status='SUPERSEDED' where id=old_result_id; end if;

  insert into public.academic_results(school_id,academic_year_id,student_id,course_offering_id,assessment_period_id,result_type,status,
    rule_version,value,display_value,classification,input_snapshot,calculated_by,supersedes_result_id)
  values(school_id,academic_year_id,p_student_id,p_course_offering_id,p_assessment_period_id,'TRIMESTER','CALCULATED',
    rule_code,mt,round(mt),private.classify_grade(rule_definition,mt),snapshot,actor,old_result_id)
  returning id into result_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CALCULATE_TRIMESTER_RESULT','academic_result',result_id,snapshot);
  result:=jsonb_build_object('academic_result_id',result_id,'result_type','TRIMESTER','status','CALCULATED',
    'value',mt,'display_value',round(mt),'rule_version',rule_code);
  perform private.complete_command('calculate_trimester_result',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) to authenticated;

create or replace function public.calculate_final_result(
  p_course_offering_id uuid,p_student_id uuid,p_frequency_result_id uuid,p_exam_assessment_result_id uuid,
  p_idempotency_key text,p_request_hash text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid(); school_id uuid; academic_year_id uuid; grade_code text; parallelism boolean;
  rule_id uuid; rule_code text; rule_definition jsonb; terminal boolean;
  nd numeric(8,4); ne numeric(8,4); nf numeric(8,4);
  ncd_weight numeric; exam_weight numeric; formula_divisor numeric;
  exam_status public.assessment_result_status; exam_epoch smallint; exam_registration_status text; second_epoch_published boolean;
  result_id uuid; old_result_id uuid; snapshot jsonb; command_state jsonb; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  select co.school_id,co.academic_year_id,gl.code,s.pedagogical_parallelism into school_id,academic_year_id,grade_code,parallelism
  from public.course_offerings co join public.class_groups cg on cg.id=co.class_group_id join public.grade_levels gl on gl.id=cg.grade_level_id
  join public.schools s on s.id=co.school_id where co.id=p_course_offering_id for share;
  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ay.grade_rule_version_id,gr.code,gr.definition into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id where ay.id=academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;
  select exists(select 1 from jsonb_array_elements_text(coalesce(rule_definition#>'{examination,terminal_classes}','[]'::jsonb)) x where x=grade_code) into terminal;
  if not terminal then raise exception 'FINAL_EXAM_NOT_ALLOWED_FOR_GRADE'; end if;
  if parallelism is null then raise exception 'PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select ar.value into nd from public.academic_results ar where ar.id=p_frequency_result_id and ar.student_id=p_student_id
    and ar.course_offering_id=p_course_offering_id and ar.academic_year_id=academic_year_id and ar.result_type='FREQUENCY' and ar.status='PUBLISHED';
  if nd is null then raise exception 'PUBLISHED_FREQUENCY_RESULT_REQUIRED'; end if;

  select ar.status,er.eligibility_status,es.epoch into exam_status,exam_registration_status,exam_epoch
  from public.assessment_results ar join public.assessments a on a.id=ar.assessment_id
  left join public.exam_registrations er on er.id=ar.exam_registration_id
  left join public.exam_sessions es on es.id=er.exam_session_id
  where ar.id=p_exam_assessment_result_id and ar.student_id=p_student_id and a.course_offering_id=p_course_offering_id and a.type='EXAM';
  if exam_status is null then raise exception 'EXAM_RESULT_NOT_FOUND'; end if;
  if exam_status<>'PUBLISHED' then raise exception 'PUBLISHED_EXAM_RESULT_REQUIRED'; end if;
  if exam_registration_status<>'ELIGIBLE' then raise exception 'EXAM_REGISTRATION_NOT_ELIGIBLE'; end if;

  select exists(select 1 from public.assessment_results ar2 join public.assessments a2 on a2.id=ar2.assessment_id
    join public.exam_registrations er2 on er2.id=ar2.exam_registration_id join public.exam_sessions es2 on es2.id=er2.exam_session_id
    where ar2.student_id=p_student_id and a2.course_offering_id=p_course_offering_id and a2.type='EXAM'
      and ar2.status='PUBLISHED' and es2.epoch=2) into second_epoch_published;
  if exam_epoch=1 and second_epoch_published then raise exception 'FIRST_EPOCH_SUPERSEDED_BY_SECOND_EPOCH'; end if;

  select ar.normalized_score into ne from public.assessment_results ar where ar.id=p_exam_assessment_result_id;
  if ne is null then raise exception 'EXAM_SCORE_REQUIRED'; end if;

  if parallelism then
    select (rule_definition#>>format('{final_coefficients,with_parallelism,%s,ncd_weight}',grade_code))::numeric,
           (rule_definition#>>format('{final_coefficients,with_parallelism,%s,exam_weight}',grade_code))::numeric,
           (rule_definition#>>format('{final_coefficients,with_parallelism,%s,divisor}',grade_code))::numeric
      into ncd_weight,exam_weight,formula_divisor;
  else
    ncd_weight:=(rule_definition#>>'{final_coefficients,without_parallelism,ncd_weight}')::numeric;
    exam_weight:=(rule_definition#>>'{final_coefficients,without_parallelism,exam_weight}')::numeric;
    formula_divisor:=(rule_definition#>>'{final_coefficients,without_parallelism,divisor}')::numeric;
  end if;
  if ncd_weight is null or exam_weight is null or formula_divisor is null then raise exception 'FINAL_FORMULA_NOT_CONFIGURED'; end if;

  command_state:=private.begin_command('calculate_final_result',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
  nf:=(ncd_weight*nd+exam_weight*ne)/formula_divisor;

  snapshot:=jsonb_build_object('rule_version_id',rule_id,'rule_version',rule_code,'grade_code',grade_code,
    'pedagogical_parallelism',parallelism,'exam_epoch',exam_epoch,'frequency_result_id',p_frequency_result_id,
    'exam_assessment_result_id',p_exam_assessment_result_id,'nd',nd,'ne',ne,'nf',nf,
    'formula',case when parallelism then rule_definition->'final_coefficients'->'with_parallelism'->grade_code
      else rule_definition->'final_coefficients'->'without_parallelism' end);

  if exists(select 1 from public.academic_results where student_id=p_student_id and course_offering_id=p_course_offering_id
      and result_type='FINAL' and status='PUBLISHED') then raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION'; end if;

  select id into old_result_id from public.academic_results where student_id=p_student_id and course_offering_id=p_course_offering_id
    and result_type='FINAL' and status in ('CALCULATED','HOMOLOGATED') order by calculated_at desc limit 1 for update;
  if old_result_id is not null then update public.academic_results set status='SUPERSEDED' where id=old_result_id; end if;

  insert into public.academic_results(school_id,academic_year_id,student_id,course_offering_id,result_type,status,rule_version,
    value,display_value,classification,input_snapshot,calculated_by,supersedes_result_id)
  values(school_id,academic_year_id,p_student_id,p_course_offering_id,'FINAL','CALCULATED',rule_code,nf,round(nf),
    private.classify_grade(rule_definition,nf),snapshot,actor,old_result_id)
  returning id into result_id;

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
