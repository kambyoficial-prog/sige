-- SIGE 0025 — assessment rules, periods and curriculum hardening

alter table public.curriculum_areas
  drop constraint if exists curriculum_areas_school_id_academic_cycle_id_code_key;

create unique index if not exists curriculum_areas_scope_uidx
  on public.curriculum_areas (
    academic_cycle_id,
    lower(trim(code)),
    coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

create index if not exists assessment_periods_year_ordinal_idx
  on public.assessment_periods (academic_year_id, ordinal);

alter table public.assessment_periods enable row level security;

drop policy if exists assessment_periods_read on public.assessment_periods;
create policy assessment_periods_read
  on public.assessment_periods
  for select to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = assessment_periods.academic_year_id
        and (
          private.has_permission('operations.read', ay.school_id)
          or private.has_permission('operations.manage', ay.school_id)
          or private.has_permission('assessment.read', ay.school_id)
          or private.has_permission('assessment.manage', ay.school_id)
        )
    )
  );

revoke insert, update, delete on public.assessment_periods from authenticated;
grant select on public.assessment_periods to authenticated;

insert into public.grade_rule_versions (code,name,version,definition,active)
values (
  'MZ-ES-2022-06-30',
  'Regulamento de Avaliação do Ensino Secundário',
  '2022-06-30',
  jsonb_build_object(
    'source','Regulamento de Avaliação do Ensino Secundário',
    'issuer','MINEDH / INDE',
    'approved_on','2022-06-30',
    'scale',jsonb_build_array(
      jsonb_build_object('min',19,'max',20,'label','EXCELENTE'),
      jsonb_build_object('min',17,'max',18,'label','MUITO_BOM'),
      jsonb_build_object('min',14,'max',16,'label','BOM'),
      jsonb_build_object('min',10,'max',13,'label','SUFICIENTE'),
      jsonb_build_object('min',0,'max',9,'label','NAO_SUFICIENTE')
    ),
    'rounding',jsonb_build_object('mode','NEAREST_INTEGER'),
    'trimester',jsonb_build_object(
      'acs_minimum',2,'at_count',1,
      'macs','sum(ACS) / count(ACS)',
      'mt','(2 * MACS + AT) / 3'
    ),
    'frequency',jsonb_build_object(
      'trimester_count',3,'mfd','(MT1 + MT2 + MT3) / 3'
    ),
    'cycle',jsonb_build_object('ncd','MFD of the last class of the cycle'),
    'final',jsonb_build_object(
      'parallelism','(2 * NCD + EXAM) / 3',
      'without_parallelism','(NCD + EXAM) / 2'
    ),
    'cycle_global',jsonb_build_object(
      'formula','arithmetic mean of final grades of the last class disciplines'
    ),
    'exams',jsonb_build_object(
      'exam_classes',jsonb_build_array(9,12),'dispensation',false
    ),
    'transition_cycle_2',jsonb_build_object(
      'global_average_min',10,'max_disciplines_below_10',2,
      'minimum_in_each_exceptional_discipline',8,
      'positive_portuguese_required',true,
      'positive_mathematics_required',true
    ),
    'recovery',jsonb_build_object(
      'implemented',false,
      'reason','No generic recovery formula encoded without a verified normative source'
    )
  ),
  true
)
on conflict (code) do nothing;

create or replace function public.initialize_assessment_periods(
  p_academic_year_id uuid,
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
  year_status public.academic_year_status;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status into school_id, year_status
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if year_status not in ('DRAFT','OPEN') then raise exception 'ACADEMIC_YEAR_NOT_EDITABLE'; end if;
  if not (select private.has_permission('operations.manage', school_id)) then raise exception 'FORBIDDEN'; end if;

  command_state := private.begin_command(
    'initialize_assessment_periods', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.assessment_periods (academic_year_id,code,name,ordinal,active)
  values
    (p_academic_year_id,'T1','1.º Trimestre',1,true),
    (p_academic_year_id,'T2','2.º Trimestre',2,true),
    (p_academic_year_id,'T3','3.º Trimestre',3,true)
  on conflict (academic_year_id, ordinal)
  do update set code=excluded.code,name=excluded.name,active=true;

  result := jsonb_build_object(
    'academic_year_id',p_academic_year_id,
    'period_count',3,
    'periods',(
      select jsonb_agg(
        jsonb_build_object('id',ap.id,'code',ap.code,'name',ap.name,'ordinal',ap.ordinal)
        order by ap.ordinal
      )
      from public.assessment_periods ap
      where ap.academic_year_id=p_academic_year_id and ap.ordinal between 1 and 3
    )
  );

  insert into public.audit_events (
    school_id,actor_auth_user_id,action,entity_type,entity_id,after_data
  )
  values (
    school_id,actor,'INITIALIZE_ASSESSMENT_PERIODS','academic_year',
    p_academic_year_id,result
  );

  perform private.complete_command(
    'initialize_assessment_periods',school_id,p_idempotency_key,result
  );
  return result;
end;
$$;

revoke all on function public.initialize_assessment_periods(uuid,text,text) from public;
grant execute on function public.initialize_assessment_periods(uuid,text,text) to authenticated;

alter table public.grade_rule_versions enable row level security;
revoke insert, update, delete on public.grade_rule_versions from authenticated;
grant select on public.grade_rule_versions to authenticated;

drop policy if exists grade_rule_versions_read on public.grade_rule_versions;
create policy grade_rule_versions_read
  on public.grade_rule_versions
  for select to authenticated
  using (true);
