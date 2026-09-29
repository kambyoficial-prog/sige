-- SIGE F6 — normative rule binding, configurable gradebook and assessment hardening
--
-- Research basis:
-- - Diploma Ministerial n.º 7/2019, 10 Jan, BR I Série n.º 7:
--   ESG arts. 49-52: minimum 3 written assessments/trimester,
--   2 ACS + 1 AT; MACS is the arithmetic mean of ACS; MT=(2*MACS+AT)/3;
--   MFD is the mean of the three trimester means.
-- - Arts. 91-98: ESG terminal examinations are in 10th and 12th classes;
--   exam admission/approval rules are distinct from trimester calculation.
--
-- This migration deliberately does NOT claim that an unverified "2022-06-30"
-- regulation is normative. Existing historical results keep their rule_version.
-- New academic years bind to the verified rule record below.

alter type public.assessment_type add value if not exists 'ACP';
alter type public.assessment_type add value if not exists 'RECOVERY';

alter table public.academic_years
  add column if not exists grade_rule_version_id uuid
    references public.grade_rule_versions(id) on delete restrict;

create index if not exists academic_years_grade_rule_idx
  on public.academic_years (grade_rule_version_id);

insert into public.grade_rule_versions (code, name, version, definition, active)
values (
  'MZ-ESG-RGA-2019',
  'Regulamento Geral de Avaliação — Ensino Secundário Geral',
  '2019',
  jsonb_build_object(
    'jurisdiction', 'MZ',
    'education_level', 'ESG',
    'source', jsonb_build_object(
      'instrument', 'Diploma Ministerial n.º 7/2019',
      'published', '2019-01-10',
      'gazette', 'BR I Série n.º 7',
      'official_registry', 'Imprensa Nacional de Moçambique',
      'status', 'verified_registry_record'
    ),
    'scale', jsonb_build_array(
      jsonb_build_object('min',19,'max',20,'label','EXCELENTE','code','E'),
      jsonb_build_object('min',17,'max',18,'label','MUITO_BOM','code','MB'),
      jsonb_build_object('min',14,'max',16,'label','BOM','code','B'),
      jsonb_build_object('min',10,'max',13,'label','SATISFATORIO','code','S'),
      jsonb_build_object('min',0,'max',9,'label','NAO_SATISFATORIO','code','NS')
    ),
    'rounding', jsonb_build_object(
      'mode','NEAREST_INTEGER',
      'display_only',true
    ),
    'trimester', jsonb_build_object(
      'period_count',3,
      'required', jsonb_build_array(
        jsonb_build_object('type','ACS','minimum_count',2,'aggregation','ARITHMETIC_MEAN'),
        jsonb_build_object('type','AT','minimum_count',1,'maximum_count',1,'aggregation','SINGLE')
      ),
      'macs', jsonb_build_object(
        'aggregation','ARITHMETIC_MEAN',
        'types',jsonb_build_array('ACS'),
        'published_only',true,
        'absent_policy','EXCLUDE',
        'invalidated_policy','EXCLUDE'
      ),
      'formula', '(2 * MACS + AT) / 3'
    ),
    'frequency', jsonb_build_object(
      'aggregation','ARITHMETIC_MEAN',
      'period_count',3,
      'formula','(MT1 + MT2 + MT3) / 3'
    ),
    'examination', jsonb_build_object(
      'terminal_classes',jsonb_build_array(10,12),
      'dispensation',false,
      'source_articles',jsonb_build_array(91,93)
    ),
    'approval', jsonb_build_object(
      'first_cycle',jsonb_build_object(
        'global_min',10,
        'exceptional_min',8,
        'max_exceptional_disciplines',2,
        'portuguese_positive_required',true,
        'mathematics_positive_required',true,
        'exam_min',8
      ),
      'second_cycle',jsonb_build_object(
        'discipline_final_min',10,
        'exam_min',9
      )
    ),
    'recovery', jsonb_build_object(
      'generic_formula_verified',false,
      'implementation','explicit_event_only'
    )
  ),
  true
)
on conflict (code) do update
set name = excluded.name,
    version = excluded.version,
    definition = excluded.definition,
    active = true;

update public.academic_years ay
set grade_rule_version_id = gr.id
from public.grade_rule_versions gr
where gr.code = 'MZ-ESG-RGA-2019'
  and ay.grade_rule_version_id is null;

comment on column public.academic_years.grade_rule_version_id is
  'Normative assessment rule frozen for this academic year. Historical years must not be silently recalculated under a newer rule.';

create table if not exists public.assessment_definitions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  course_offering_id uuid not null references public.course_offerings(id) on delete restrict,
  assessment_period_id uuid not null references public.assessment_periods(id) on delete restrict,
  grade_rule_version_id uuid not null references public.grade_rule_versions(id) on delete restrict,
  code text not null,
  name text not null,
  type public.assessment_type not null,
  ordinal integer not null,
  required boolean not null default false,
  counts_in_macs boolean not null default false,
  max_score numeric(8,4) not null default 20,
  weight numeric(8,4),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_offering_id, assessment_period_id, code),
  constraint assessment_definitions_ordinal_ck check (ordinal > 0),
  constraint assessment_definitions_score_ck check (max_score > 0),
  constraint assessment_definitions_weight_ck check (weight is null or weight >= 0)
);

create index if not exists assessment_definitions_lookup_idx
  on public.assessment_definitions (
    academic_year_id, course_offering_id, assessment_period_id, ordinal
  );

alter table public.assessment_definitions enable row level security;

drop policy if exists assessment_definitions_read on public.assessment_definitions;
create policy assessment_definitions_read
on public.assessment_definitions
for select to authenticated
using (
  private.has_permission('assessment.read', school_id)
  or private.has_permission('assessment.manage', school_id)
);

revoke insert, update, delete on public.assessment_definitions from authenticated;
grant select on public.assessment_definitions to authenticated;

alter table public.assessments
  add column if not exists definition_id uuid
    references public.assessment_definitions(id) on delete restrict;

create index if not exists assessments_definition_idx
  on public.assessments (definition_id);

create or replace function public.create_assessment_definition(
  p_course_offering_id uuid,
  p_assessment_period_id uuid,
  p_code text,
  p_name text,
  p_type public.assessment_type,
  p_ordinal integer,
  p_required boolean default false,
  p_counts_in_macs boolean default false,
  p_max_score numeric default 20,
  p_weight numeric default null,
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
  school_id uuid;
  year_id uuid;
  rule_id uuid;
  period_year uuid;
  definition_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  if p_code is null or length(trim(p_code)) < 1 then raise exception 'INVALID_ASSESSMENT_DEFINITION_CODE'; end if;
  if p_name is null or length(trim(p_name)) < 2 then raise exception 'INVALID_ASSESSMENT_DEFINITION_NAME'; end if;
  if p_ordinal <= 0 or p_max_score <= 0 then raise exception 'INVALID_ASSESSMENT_DEFINITION'; end if;
  if p_weight is not null and p_weight < 0 then raise exception 'INVALID_WEIGHT'; end if;

  select co.school_id, co.academic_year_id
    into school_id, year_id
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ap.academic_year_id
    into period_year
  from public.assessment_periods ap
  where ap.id = p_assessment_period_id
  for share;

  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if period_year <> year_id then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  select ay.grade_rule_version_id
    into rule_id
  from public.academic_years ay
  where ay.id = year_id;

  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  command_state := private.begin_command(
    'create_assessment_definition', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then
    return command_state->'result';
  end if;

  insert into public.assessment_definitions (
    school_id, academic_year_id, course_offering_id, assessment_period_id,
    grade_rule_version_id, code, name, type, ordinal, required,
    counts_in_macs, max_score, weight
  )
  values (
    school_id, year_id, p_course_offering_id, p_assessment_period_id,
    rule_id, trim(p_code), trim(p_name), p_type, p_ordinal, p_required,
    p_counts_in_macs, p_max_score, p_weight
  )
  returning id into definition_id;

  result := jsonb_build_object(
    'assessment_definition_id', definition_id,
    'grade_rule_version_id', rule_id,
    'type', p_type,
    'required', p_required
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CREATE_ASSESSMENT_DEFINITION',
    'assessment_definition', definition_id, result
  );

  perform private.complete_command(
    'create_assessment_definition', school_id, p_idempotency_key, result
  );
  return result;
end;
$$;

revoke all on function public.create_assessment_definition(
  uuid,uuid,text,text,public.assessment_type,integer,boolean,boolean,numeric,numeric,text,text
) from public;
grant execute on function public.create_assessment_definition(
  uuid,uuid,text,text,public.assessment_type,integer,boolean,boolean,numeric,numeric,text,text
) to authenticated;

create or replace function public.create_assessment(
  p_course_offering_id uuid,
  p_assessment_period_id uuid,
  p_type public.assessment_type,
  p_title text,
  p_assessment_date date default null,
  p_max_score numeric(8,4) default 20,
  p_weight numeric(8,4) default null,
  p_definition_id uuid default null,
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
  school_id uuid;
  offering_year uuid;
  offering_status public.course_offering_status;
  period_year uuid;
  period_active boolean;
  definition_type public.assessment_type;
  definition_year uuid;
  assessment_id uuid;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_title is null or length(trim(p_title)) < 2 then raise exception 'INVALID_ASSESSMENT_TITLE'; end if;
  if p_max_score <= 0 then raise exception 'INVALID_MAX_SCORE'; end if;
  if p_weight is not null and p_weight < 0 then raise exception 'INVALID_WEIGHT'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id, co.status
    into school_id, offering_year, offering_status
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  if offering_status not in ('OPEN','ACTIVE') then raise exception 'COURSE_OFFERING_NOT_OPEN'; end if;

  select ap.academic_year_id, ap.active
    into period_year, period_active
  from public.assessment_periods ap
  where ap.id = p_assessment_period_id
  for share;

  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if not period_active then raise exception 'ASSESSMENT_PERIOD_INACTIVE'; end if;
  if offering_year <> period_year then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;

  if p_definition_id is not null then
    select ad.type, ad.academic_year_id
      into definition_type, definition_year
    from public.assessment_definitions ad
    where ad.id = p_definition_id
      and ad.active
      and ad.course_offering_id = p_course_offering_id
      and ad.assessment_period_id = p_assessment_period_id;

    if definition_type is null then raise exception 'ASSESSMENT_DEFINITION_NOT_FOUND'; end if;
    if definition_year <> offering_year then raise exception 'ASSESSMENT_DEFINITION_YEAR_MISMATCH'; end if;
    if definition_type <> p_type then raise exception 'ASSESSMENT_DEFINITION_TYPE_MISMATCH'; end if;
  end if;

  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command(
    'create_assessment', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  insert into public.assessments (
    course_offering_id, assessment_period_id, definition_id, type, title,
    assessment_date, max_score, weight, status, created_by
  )
  values (
    p_course_offering_id, p_assessment_period_id, p_definition_id, p_type, trim(p_title),
    p_assessment_date, p_max_score, p_weight, 'OPEN', actor
  )
  returning id into assessment_id;

  result := jsonb_build_object(
    'assessment_id', assessment_id,
    'status', 'OPEN',
    'max_score', p_max_score,
    'definition_id', p_definition_id
  );

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CREATE_ASSESSMENT', 'assessment', assessment_id, result
  );

  perform private.complete_command('create_assessment', school_id, p_idempotency_key, result);
  return result;
end;
$$;

drop function if exists public.create_assessment(
  uuid,uuid,public.assessment_type,text,date,numeric,numeric,text,text
);

revoke all on function public.create_assessment(
  uuid,uuid,public.assessment_type,text,date,numeric,numeric,uuid,text,text
) from public;
grant execute on function public.create_assessment(
  uuid,uuid,public.assessment_type,text,date,numeric,numeric,uuid,text,text
) to authenticated;

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
  ar.published_at as assessment_published_at,
  scp.student_id,
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
left join public.assessment_results ar
  on ar.assessment_id = a.id
 and ar.student_id = scp.student_id
where scp.status in ('ACTIVE','ENDED');

grant select on public.assessment_gradebook to authenticated;

create or replace function public.calculate_trimester_result(
  p_course_offering_id uuid,
  p_student_id uuid,
  p_assessment_period_id uuid,
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
  period_year uuid;
  rule_id uuid;
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

  select co.school_id, co.academic_year_id
    into school_id, academic_year_id
  from public.course_offerings co
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;

  select ap.academic_year_id
    into period_year
  from public.assessment_periods ap
  where ap.id = p_assessment_period_id
  for share;

  if period_year is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if period_year <> academic_year_id then raise exception 'ASSESSMENT_YEAR_MISMATCH'; end if;

  select ay.grade_rule_version_id, gr.definition
    into rule_id, rule_definition
  from public.academic_years ay
  join public.grade_rule_versions gr on gr.id = ay.grade_rule_version_id
  where ay.id = academic_year_id;

  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  acs_min := coalesce((rule_definition #>> '{trimester,required,0,minimum_count}')::integer,2);
  at_min := coalesce((rule_definition #>> '{trimester,required,1,minimum_count}')::integer,1);
  at_max := nullif((rule_definition #>> '{trimester,required,1,maximum_count}')::integer,0);

  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  select exists (
    select 1
    from public.student_course_participations scp
    join public.assessment_periods ap on ap.id = p_assessment_period_id
    where scp.student_id = p_student_id
      and scp.course_offering_id = p_course_offering_id
      and scp.starts_on <= coalesce(ap.ends_on, '9999-12-31'::date)
      and (scp.ends_on is null or scp.ends_on >= coalesce(ap.starts_on, scp.starts_on))
      and scp.status in ('ACTIVE','ENDED')
  ) into participant;

  if not participant then raise exception 'STUDENT_NOT_COURSE_PARTICIPANT'; end if;

  command_state := private.begin_command(
    'calculate_trimester_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  select
    count(*) filter (
      where a.type = 'ACS'
        and ar.status = 'PUBLISHED'
        and ar.normalized_score is not null
    ),
    avg(ar.normalized_score) filter (
      where a.type = 'ACS'
        and ar.status = 'PUBLISHED'
        and ar.normalized_score is not null
    ),
    count(*) filter (
      where a.type = 'AT'
        and ar.status = 'PUBLISHED'
        and ar.normalized_score is not null
    ),
    max(ar.normalized_score) filter (
      where a.type = 'AT'
        and ar.status = 'PUBLISHED'
        and ar.normalized_score is not null
    )
  into acs_count, macs, at_count, at_value
  from public.assessments a
  join public.assessment_results ar on ar.assessment_id = a.id
  where a.course_offering_id = p_course_offering_id
    and a.assessment_period_id = p_assessment_period_id
    and ar.student_id = p_student_id;

  if acs_count < acs_min then raise exception 'TRIMESTER_ACS_INCOMPLETE'; end if;
  if at_count < at_min or (at_max is not null and at_count > at_max) then
    raise exception 'TRIMESTER_AT_INVALID';
  end if;

  mt := (2 * macs + at_value) / 3;

  snapshot := jsonb_build_object(
    'rule_version_id', rule_id,
    'rule_version', (select code from public.grade_rule_versions where id = rule_id),
    'assessment_period_id', p_assessment_period_id,
    'course_offering_id', p_course_offering_id,
    'student_id', p_student_id,
    'acs_count', acs_count,
    'macs', macs,
    'at', at_value,
    'mt', mt,
    'rounding', rule_definition->'rounding',
    'assessments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'assessment_id', a.id,
          'type', a.type,
          'title', a.title,
          'result_id', ar.id,
          'status', ar.status,
          'normalized_score', ar.normalized_score
        )
        order by a.assessment_date nulls last, a.created_at, a.id
      )
      from public.assessments a
      join public.assessment_results ar on ar.assessment_id = a.id
      where a.course_offering_id = p_course_offering_id
        and a.assessment_period_id = p_assessment_period_id
        and ar.student_id = p_student_id
    ), '[]'::jsonb)
  );

  if exists (
    select 1 from public.academic_results
    where student_id = p_student_id
      and course_offering_id = p_course_offering_id
      and assessment_period_id = p_assessment_period_id
      and result_type = 'TRIMESTER'
      and status = 'PUBLISHED'
  ) then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION';
  end if;

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and assessment_period_id = p_assessment_period_id
    and result_type = 'TRIMESTER'
    and status in ('CALCULATED','HOMOLOGATED')
  order by calculated_at desc
  limit 1
  for update;

  if old_result_id is not null then
    update public.academic_results set status = 'SUPERSEDED' where id = old_result_id;
  end if;

  insert into public.academic_results (
    school_id, academic_year_id, student_id, course_offering_id,
    assessment_period_id, result_type, status, rule_version,
    value, display_value, classification, input_snapshot,
    calculated_by, supersedes_result_id
  )
  values (
    school_id, academic_year_id, p_student_id, p_course_offering_id,
    p_assessment_period_id, 'TRIMESTER', 'CALCULATED',
    (select code from public.grade_rule_versions where id = rule_id),
    mt, round(mt),
    case
      when round(mt) >= 19 then 'EXCELENTE'
      when round(mt) >= 17 then 'MUITO_BOM'
      when round(mt) >= 14 then 'BOM'
      when round(mt) >= 10 then 'SATISFATORIO'
      else 'NAO_SATISFATORIO'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_TRIMESTER_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'TRIMESTER',
    'status', 'CALCULATED',
    'value', mt,
    'display_value', round(mt),
    'rule_version', (select code from public.grade_rule_versions where id = rule_id)
  );

  perform private.complete_command(
    'calculate_trimester_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_trimester_result(uuid,uuid,uuid,text,text) to authenticated;

-- The prior implementation incorrectly treated the 9th class as an exam class.
-- The verified 2019 regulation identifies the terminal classes as 10th and 12th.
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
  actor uuid := (select auth.uid());
  school_id uuid;
  academic_year_id uuid;
  grade_code text;
  pedagogical_parallelism boolean;
  rule_id uuid;
  rule_code text;
  nd numeric(8,4);
  ne numeric(8,4);
  nf numeric(8,4);
  exam_assessment_id uuid;
  exam_type public.assessment_type;
  exam_status public.assessment_result_status;
  result_id uuid;
  old_result_id uuid;
  snapshot jsonb;
  command_state jsonb;
  result jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select co.school_id, co.academic_year_id, gl.code, s.pedagogical_parallelism
    into school_id, academic_year_id, grade_code, pedagogical_parallelism
  from public.course_offerings co
  join public.class_groups cg on cg.id = co.class_group_id
  join public.grade_levels gl on gl.id = cg.grade_level_id
  join public.schools s on s.id = co.school_id
  where co.id = p_course_offering_id
  for share;

  if school_id is null then raise exception 'COURSE_OFFERING_NOT_FOUND'; end if;
  if grade_code not in ('10','12') then
    raise exception 'FINAL_EXAM_ONLY_ALLOWED_FOR_10_AND_12';
  end if;
  if pedagogical_parallelism is null then
    raise exception 'PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED';
  end if;

  select ay.grade_rule_version_id, gr.code
    into rule_id, rule_code
  from public.academic_years ay
  join public.grade_rule_versions gr on gr.id = ay.grade_rule_version_id
  where ay.id = academic_year_id;

  if rule_id is null then raise exception 'GRADE_RULE_NOT_CONFIGURED'; end if;

  if not (select private.has_permission('assessment.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  select ar.value
    into nd
  from public.academic_results ar
  where ar.id = p_frequency_result_id
    and ar.student_id = p_student_id
    and ar.course_offering_id = p_course_offering_id
    and ar.academic_year_id = academic_year_id
    and ar.result_type = 'FREQUENCY'
    and ar.status = 'PUBLISHED';

  if nd is null then raise exception 'PUBLISHED_FREQUENCY_RESULT_REQUIRED'; end if;

  select ar.assessment_id, ar.normalized_score, a.type, ar.status
    into exam_assessment_id, ne, exam_type, exam_status
  from public.assessment_results ar
  join public.assessments a on a.id = ar.assessment_id
  where ar.id = p_exam_assessment_result_id
    and ar.student_id = p_student_id
    and a.course_offering_id = p_course_offering_id;

  if exam_assessment_id is null then raise exception 'EXAM_RESULT_NOT_FOUND'; end if;
  if exam_type <> 'EXAM' then raise exception 'ASSESSMENT_RESULT_IS_NOT_EXAM'; end if;
  if exam_status <> 'PUBLISHED' then raise exception 'PUBLISHED_EXAM_RESULT_REQUIRED'; end if;
  if ne is null then raise exception 'EXAM_SCORE_REQUIRED'; end if;

  command_state := private.begin_command(
    'calculate_final_result', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  nf := case
    when pedagogical_parallelism then (2 * nd + ne) / 3
    else (nd + ne) / 2
  end;

  snapshot := jsonb_build_object(
    'rule_version_id', rule_id,
    'rule_version', rule_code,
    'pedagogical_parallelism', pedagogical_parallelism,
    'grade_code', grade_code,
    'frequency_result_id', p_frequency_result_id,
    'exam_assessment_result_id', p_exam_assessment_result_id,
    'nd', nd,
    'ne', ne,
    'nf', nf
  );

  if exists (
    select 1 from public.academic_results
    where student_id = p_student_id
      and course_offering_id = p_course_offering_id
      and result_type = 'FINAL'
      and status = 'PUBLISHED'
  ) then
    raise exception 'PUBLISHED_RESULT_REQUIRES_CORRECTION';
  end if;

  select id into old_result_id
  from public.academic_results
  where student_id = p_student_id
    and course_offering_id = p_course_offering_id
    and result_type = 'FINAL'
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
    'FINAL', 'CALCULATED', rule_code,
    nf, round(nf),
    case
      when round(nf) >= 19 then 'EXCELENTE'
      when round(nf) >= 17 then 'MUITO_BOM'
      when round(nf) >= 14 then 'BOM'
      when round(nf) >= 10 then 'SATISFATORIO'
      else 'NAO_SATISFATORIO'
    end,
    snapshot, actor, old_result_id
  )
  returning id into result_id;

  insert into public.audit_events (
    school_id, actor_auth_user_id, action, entity_type, entity_id, after_data
  )
  values (
    school_id, actor, 'CALCULATE_FINAL_RESULT',
    'academic_result', result_id, snapshot
  );

  result := jsonb_build_object(
    'academic_result_id', result_id,
    'result_type', 'FINAL',
    'status', 'CALCULATED',
    'value', nf,
    'display_value', round(nf),
    'rule_version', rule_code
  );

  perform private.complete_command(
    'calculate_final_result', school_id, p_idempotency_key, result
  );

  return result;
end;
$$;

revoke all on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) from public;
grant execute on function public.calculate_final_result(uuid,uuid,uuid,uuid,text,text) to authenticated;

alter table public.grade_rule_versions enable row level security;

drop policy if exists grade_rules_read_active on public.grade_rule_versions;
create policy grade_rules_read_active
on public.grade_rule_versions
for select to authenticated
using (active);

grant select on public.grade_rule_versions to authenticated;

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
  a.published_at as assessment_published_at,
  scp.student_id,
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
left join public.assessment_results ar
  on ar.assessment_id = a.id
 and ar.student_id = scp.student_id
where scp.status in ('ACTIVE','ENDED');

grant select on public.assessment_gradebook to authenticated;
