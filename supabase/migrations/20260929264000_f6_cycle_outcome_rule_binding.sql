
create or replace function public.calculate_cycle_outcome(
  p_student_id uuid,p_academic_year_id uuid,p_grade_level_id uuid,
  p_idempotency_key text,p_request_hash text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  actor uuid:=auth.uid(); school_id uuid; grade_code text;
  rule_id uuid; rule_code text; rule_definition jsonb;
  global_average numeric(8,4); result_count integer; failed_count integer; exam_below_min integer;
  global_min numeric; final_min numeric; exam_min numeric;
  approved boolean; outcome_id uuid; old_id uuid; snapshot jsonb; command_state jsonb; result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select ay.school_id,gl.code into school_id,grade_code
  from public.academic_years ay join public.grade_levels gl on gl.id=p_grade_level_id
  where ay.id=p_academic_year_id;
  if school_id is null then raise exception 'ACADEMIC_CONTEXT_NOT_FOUND'; end if;
  if not private.has_permission('assessment.manage',school_id) then raise exception 'FORBIDDEN'; end if;

  select ay.grade_rule_version_id,gr.code,gr.definition into rule_id,rule_code,rule_definition
  from public.academic_years ay join public.grade_rule_versions gr on gr.id=ay.grade_rule_version_id
  where ay.id=p_academic_year_id;
  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  global_min:=coalesce((rule_definition#>>case when grade_code='10' then '{approval,first_cycle,global_min}' else '{approval,second_cycle,global_min}' end)::numeric,10);
  final_min:=coalesce((rule_definition#>>'{approval,second_cycle,all_final_min}')::numeric,10);
  exam_min:=coalesce((rule_definition#>>case when grade_code='10' then '{approval,first_cycle,exam_min}' else '{approval,second_cycle,exam_min}' end)::numeric,
    case when grade_code='10' then 8 else 9 end);

  select count(*),avg(ar.value),count(*) filter(where round(ar.value)<10)
    into result_count,global_average,failed_count
  from public.academic_results ar
  join public.course_offerings co on co.id=ar.course_offering_id
  join public.class_groups cg on cg.id=co.class_group_id
  where ar.student_id=p_student_id and ar.academic_year_id=p_academic_year_id
    and ar.result_type='FINAL' and ar.status='PUBLISHED' and cg.grade_level_id=p_grade_level_id;
  if result_count=0 or global_average is null then raise exception 'FINAL_RESULTS_INCOMPLETE'; end if;

  select count(*) into exam_below_min
  from public.assessment_results ar
  join public.assessments a on a.id=ar.assessment_id
  join public.course_offerings co on co.id=a.course_offering_id
  join public.class_groups cg on cg.id=co.class_group_id
  where ar.student_id=p_student_id and co.academic_year_id=p_academic_year_id
    and cg.grade_level_id=p_grade_level_id and a.type='EXAM'
    and ar.status='PUBLISHED' and ar.normalized_score<exam_min;

  approved:=case
    when grade_code='10' then round(global_average)>=global_min and failed_count=0 and exam_below_min=0
    when grade_code='12' then round(global_average)>=global_min and failed_count=0 and exam_below_min=0
    else false
  end;

  command_state:=private.begin_command('calculate_cycle_outcome',school_id,p_idempotency_key,p_request_hash);
  if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;

  select id into old_id from public.cycle_outcomes where student_id=p_student_id and academic_year_id=p_academic_year_id
    and grade_level_id=p_grade_level_id order by calculated_at desc limit 1 for update;
  if old_id is not null then update public.cycle_outcomes set status='INCOMPLETE' where id=old_id; end if;

  snapshot:=jsonb_build_object('rule_version_id',rule_id,'rule_version',rule_code,'grade_code',grade_code,
    'global_average',global_average,'global_min',global_min,'final_result_count',result_count,
    'failed_final_results',failed_count,'exam_minimum',exam_min,'exam_below_minimum',exam_below_min);

  insert into public.cycle_outcomes(school_id,academic_year_id,student_id,grade_level_id,status,global_average,
    display_global_average,rule_version,input_snapshot,calculated_by,supersedes_outcome_id)
  values(school_id,p_academic_year_id,p_student_id,p_grade_level_id,case when approved then 'APPROVED' else 'FAILED' end,
    global_average,round(global_average),rule_code,snapshot,actor,old_id)
  returning id into outcome_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
  values(school_id,actor,'CALCULATE_CYCLE_OUTCOME','cycle_outcome',outcome_id,snapshot);

  result:=jsonb_build_object('cycle_outcome_id',outcome_id,'status',case when approved then 'APPROVED' else 'FAILED' end,
    'global_average',global_average,'display_global_average',round(global_average));
  perform private.complete_command('calculate_cycle_outcome',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.calculate_cycle_outcome(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_cycle_outcome(uuid,uuid,uuid,text,text) to authenticated;
