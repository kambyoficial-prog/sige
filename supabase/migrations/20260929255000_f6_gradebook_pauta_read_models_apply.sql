-- SIGE F6 — gradebook/pauta read models and normative binding for annual frequency

create or replace function public.calculate_frequency_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_first_trimester_result_id uuid,
  p_second_trimester_result_id uuid,
  p_third_trimester_result_id uuid,
  p_idempotency_key text,
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
  academic_year_id uuid;
  rule_id uuid;
  rule_code text;
  values_count integer;
  mfd numeric(8,4);
  snapshot jsonb;
  old_result_id uuid;
  result_id uuid;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id
    into school_id, academic_year_id
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ay.grade_rule_version_id, gr.code
    into rule_id, rule_code
  from public.academic_years ay
  join public.grade_rule_versions gr on gr.id = ay.grade_rule_version_id
  where ay.id = academic_year_id;

  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then raise exception 'FORBIDDEN'; end if;

  if not exists (
    select 1
    from public.academic_results ar
    join public.assessment_periods ap on ap.id = ar.assessment_period_id
    where ar.id in (
      p_first_trimester_result_id,
      p_second_trimester_result_id,
      p_third_trimester_result_id
    )
    group by ar.student_id, ar.course_offering_id, ar.academic_year_id
    having count(*) = 3
       and bool_and(ar.student_id = p_student_id)
       and bool_and(ar.course_offering_id = p_course_offering_id)
       and bool_and(ar.academic_year_id = academic_year_id)
       and bool_and(ar.result_type = 'TRIMESTER')
       and bool_and(ar.status = 'PUBLISHED')
       and array_agg(distinct ap.ordinal order by ap.ordinal) = array[1,2,3]
  ) then
    raise exception 'THREE_PUBLISHED_TRIMESTER_RESULTS_REQUIRED';
  end if;

  command_state := private.begin_command(
    'calculate_frequency_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  select count(*), avg(ar.value)
    into values_count, mfd
  from public.academic_results ar
  where ar.id in (
    p_first_trimester_result_id,
    p_second_trimester_result_id,
    p_third_trimester_result_id
  )
    and ar.status = 'PUBLISHED'
    and ar.result_type = 'TRIMESTER';

  if values_count <> 3 or mfd is null then raise exception 'FREQUENCY_RESULT_INCOMPLETE'; end if;

  snapshot := jsonb_build_object(
    'rule_version_id', rule_id,
    'rule_version', rule_code,
    'source_results', jsonb_build_array(
      p_first_trimester_result_id,
      p_second_trimester_result_id,
      p_third_trimester_result_id
    ),
    'values', (
      select jsonb_agg(ar.value order by ap.ordinal)
      from public.academic_results ar
      join public.assessment_periods ap on ap.id = ar.assessment_period_id
      where ar.id in (
        p_first_trimester_result_id,
        p_second_trimester_result_id,
        p_third_trimester_result_id
      )
    ),
    'mfd', mfd
  );

  if exists (
    select 1 from public.academic_results
    where student_id = p_student_id
      and course_offering_id = p_course_offering_id
      and result_type = 'FREQUENCY'
      and status = 'PUBLISHED'
  ) then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION';
  end if;

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and result_type = 'FREQUENCY'
    and status in ('CALCULATED','HOMOLOGATED')
  order by calculated_at desc
  limit 1
  for update;

  if old_result_id is not null then
    update public.academic_results set status = 'SUPERSEDED' where id = old_result_id;
  end if;

  insert into public.academic_results (
    school_id, academic_year_id, student_id, course_offering_id,
    result_type, status, rule_version, value, display_value,
    classification, input_snapshot, calculated_by, supersedes_result_id
  )
  values (
    school_id, academic_year_id, p_student_id, p_course_offering_id,
    'FREQUENCY', 'CALCULATED', rule_code,
    mfd, round(mfd),
    case
      when round(mfd) >= 19 then 'EXCELENTE'
      when round(mfd) >= 17 then 'MUITO_BOM'
      when round(mfd) >= 14 then 'BOM'
      when round(mfd) >= 10 then 'SATISFATORIO'
      else 'NAO_SATISFATORIO'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_FREQUENCY_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'FREQUENCY',
    'status', 'CALCULATED',
    'value', mfd,
    'display_value', round(mfd),
    'rule_version', rule_code
  );

  perform private.complete_command(
    'calculate_frequency_result', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

revoke all on function public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text) to authenticated;

drop view if exists public.assessment_gradebook;
create or replace view public.assessment_gradebook
with (security_invoker = true)
as
select
  a.id as assessment_id,
  a.course_offering_id,
  a.assessment_period_id,
  a.definition_id,
  a.type,
  a.title,
  a.assessment_date,
  a.max_score,
  a.status as assessment_status,
  a.created_at as assessment_created_at,
  scp.student_id,
  s.school_number as student_number,
  p.full_name as student_name,
  cg.id as class_group_id,
  cg.name as class_name,
  co.subject_id,
  sub.name as subject_name,
  ar.id as assessment_result_id,
  ar.raw_score,
  ar.normalized_score,
  ar.status as result_status,
  ar.comment,
  ar.entered_at,
  ar.published_at as result_published_at
from public.assessments a
join public.student_course_participations scp
  on scp.course_offering_id = a.course_offering_id
join public.students s on s.id = scp.student_id
join public.people p on p.id = s.person_id
join public.course_offerings co on co.id = a.course_offering_id
join public.class_groups cg on cg.id = co.class_group_id
join public.subjects sub on sub.id = co.subject_id
left join public.assessment_results ar
  on ar.assessment_id = a.id
 and ar.student_id = scp.student_id
where scp.status in ('ACTIVE','ENDED');

grant select on public.assessment_gradebook to authenticated;

drop view if exists public.academic_result_pauta;
create or replace view public.academic_result_pauta
with (security_invoker = true)
as
select
  ar.id as academic_result_id,
  ar.school_id,
  ar.academic_year_id,
  ay.label as academic_year_label,
  ar.student_id,
  s.school_number as student_number,
  p.full_name as student_name,
  cg.id as class_group_id,
  cg.name as class_name,
  gl.code as grade_code,
  gl.name as grade_name,
  ar.course_offering_id,
  sub.code as subject_code,
  sub.name as subject_name,
  ar.assessment_period_id,
  ap.code as assessment_period_code,
  ap.name as assessment_period_name,
  ap.ordinal as assessment_period_ordinal,
  ar.result_type,
  ar.status,
  ar.rule_version,
  ar.value,
  ar.display_value,
  ar.classification,
  ar.calculated_at,
  ar.homologated_at,
  ar.published_at
from public.academic_results ar
join public.academic_years ay on ay.id = ar.academic_year_id
join public.students s on s.id = ar.student_id
join public.people p on p.id = s.person_id
join public.course_offerings co on co.id = ar.course_offering_id
join public.class_groups cg on cg.id = co.class_group_id
join public.grade_levels gl on gl.id = cg.grade_level_id
join public.subjects sub on sub.id = co.subject_id
left join public.assessment_periods ap on ap.id = ar.assessment_period_id
where ar.status = 'PUBLISHED';

grant select on public.academic_result_pauta to authenticated;

