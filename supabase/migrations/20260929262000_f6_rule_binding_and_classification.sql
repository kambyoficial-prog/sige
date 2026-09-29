
-- Bind final formulas to the frozen rule definition and use rule scale for classifications.

update public.grade_rule_versions
set definition = jsonb_set(
  definition,
  '{final}',
  jsonb_build_object(
    'with_parallelism', jsonb_build_object(
      '10', '(3 * NCD + NE) / 4',
      '12', '(2 * NCD + NE) / 3'
    ),
    'without_parallelism', '(NCD + NE) / 2'
  ),
  true
)
where code='MZ-ESG-RGA-2019';

create or replace function public.calculate_trimester_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_assessment_period_id uuid,
  p_idempotency_key text,
  p_request_hash text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid();
  school_id uuid;
  academic_year_id uuid;
  period_year uuid;
  rule_id uuid;
  rule_code text;
  rule_definition jsonb;
  participant boolean;
  acs_count integer;
  at_count integer;
  acs_min integer;
  at_min integer;
  at_max integer;
  macs numeric(8,4);
  at_value numeric(8,4);
  mt numeric(8,4);
  result_id uuid;
  old_result_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id,co.academic_year_id into school_id,academic_year_id
  from public.course_offerings co where co.id=p_course_offering_id for share;
  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ap.academic_year_id into period_year from public.assessment_periods ap
  where ap.id=p_assessment_period_id for share;
  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if period_year<>academic_year_id then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;

  select ay.grade_rule_version_id,gr.code,gr.definition
    into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id
  where ay.id=academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  acs_min:=coalesce((rule_definition#>>'{trimester,required,0,minimum_count}')::integer,2);
  at_min:=coalesce((rule_definition#>>'{trimester,required,1,minimum_count}')::integer,1);
  at_max:=nullif((rule_definition#>>'{trimester,required,1,maximum_count}')::integer,0);

  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select exists(
    select 1 from public.student_course_participations scp
    join public.assessment_periods ap on ap.id=p_assessment_period_id
    where scp.student_id=p_student_id and scp.course_offering_id=p_course_offering_id
      and scp.starts_on<=coalesce(ap.ends_on,'9999-12-31'::date)
      and (scp.ends_on is null or scp.ends_on>=coalesce(ap.starts_on,scp.starts_on))
      and scp.status in ('ACTIVE','ENDED')
  ) into participant;
  if not participant then raise exception 'STUDENT_NOT_COURSE_PARTICIPANT'; end if;

  command_state:=private.begin_command('calculate_trimester_result',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  select
    count(*) filter(where a.type='ACS' and ar.status='PUBLISHED' and ar.normalized_score is not null),
    avg(ar.normalized_score) filter(where a.type='ACS' and ar.status='PUBLISHED' and ar.normalized_score is not null),
    count(*) filter(where a.type='AT' and ar.status='PUBLISHED' and ar.normalized_score is not null),
    max(ar.normalized_score) filter(where a.type='AT' and ar.status='PUBLISHED' and ar.normalized_score is not null)
  into acs_count,macs,at_count,at_value
  from public.assessments a
  join public.assessment_results ar on ar.assessment_id=a.id
  where a.course_offering_id=p_course_offering_id
    and a.assessment_period_id=p_assessment_period_id and ar.student_id=p_student_id;

  if acs_count<acs_min then raise exception 'TRIMESTER_ACS_INCOMPLETE'; end if;
  if at_count<at_min or (at_max is not null and at_count>at_max) then raise exception 'TRIMESTER_AT_INVALID'; end if;

  mt:=(2*macs+at_value)/3;

  snapshot:=jsonb_build_object(
    'rule_version_id',rule_id,'rule_version',rule_code,
    'assessment_period_id',p_assessment_period_id,'course_offering_id',p_course_offering_id,
    'student_id',p_student_id,'acs_count',acs_count,'macs',macs,'at',at_value,'mt',mt,
    'rounding',rule_definition->'rounding',
    'assessments',coalesce((
      select jsonb_agg(jsonb_build_object('assessment_id',a.id,'type',a.type,'title',a.title,
        'result_id',ar.id,'status',ar.status,'normalized_score',ar.normalized_score)
      order by a.assessment_date nulls last,a.created_at,a.id)
      from public.assessments a join public.assessment_results ar on ar.assessment_id=a.id
      where a.course_offering_id=p_course_offering_id and a.assessment_period_id=p_assessment_period_id
        and ar.student_id=p_student_id
    ),'[]'::jsonb)
  );

  if exists(select 1 from public.academic_results where student_id=p_student_id
      and course_offering_id=p_course_offering_id and assessment_period_id=p_assessment_period_id
      and result_type='TRIMESTER' and status='PUBLISHED')
    then raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION'; end if;

  select id into old_result_id from public.academic_results
  where student_id=p_student_id and course_offering_id=p_course_offering_id
    and assessment_period_id=p_assessment_period_id and result_type='TRIMESTER'
    and status in ('CALCULATED','HOMOLOGATED')
  order by calculated_at desc limit 1 for update;
  if old_result_id is not null then update public.academic_results set status='SUPERSEDED' where id=old_result_id; end if;

  insert into public.academic_results(
    school_id,academic_year_id,student_id,course_offering_id,assessment_period_id,
    result_type,status,rule_version,value,display_value,classification,input_snapshot,
    calculated_by,supersedes_result_id
  )
  values(
    school_id,academic_year_id,p_student_id,p_course_offering_id,p_assessment_period_id,
    'TRIMESTER','CALCULATED',rule_code,mt,round(mt),private.classify_grade(rule_definition,mt),
    snapshot,actor,old_result_id
  ) returning id into result_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CALCULATE_TRIMESTER_RESULT','academic_result',result_id,snapshot);

  result:=jsonb_build_object('academic_result_id',result_id,'result_type','TRIMESTER',
    'status','CALCULATED','value',mt,'display_value',round(mt),'rule_version',rule_code);
  perform private.complete_command('calculate_trimester_result',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) to authenticated;

-- Add the verified terminal-cycle approval thresholds to the frozen 2019 rule.
update public.grade_rule_versions
set definition = jsonb_set(
  definition,
  '{approval,first_cycle}',
  jsonb_build_object(
    'global_min',10,
    'all_final_positive',true,
    'exam_min',8
  ),
  true
)
where code='MZ-ESG-RGA-2019';

update public.grade_rule_versions
set definition = jsonb_set(
  definition,
  '{approval,second_cycle}',
  jsonb_build_object(
    'all_final_min',10,
    'exam_min',9,
    'global_min',10
  ),
  true
)
where code='MZ-ESG-RGA-2019';
