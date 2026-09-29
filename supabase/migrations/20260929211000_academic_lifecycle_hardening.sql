-- SIGE 0028 — academic lifecycle and result integrity hardening

-- Only one academic year may be OPEN for a school at a time.
create unique index if not exists academic_years_one_open_per_school_uidx
  on public.academic_years (school_id)
  where status = 'OPEN';

-- SECURITY DEFINER functions use an empty search_path. Every referenced schema
-- is therefore explicit, reducing search-path hijacking risk.
create or replace function public.open_academic_year(
  p_academic_year_id uuid,
  p_idempotency_key text default null,
  p_request_hash text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  year_status public.academic_year_status;
  year_start date;
  year_end date;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status, ay.starts_on, ay.ends_on
    into school_id, year_status, year_start, year_end
  from public.academic_years ay
  where ay.id = p_academic_year_id
  for update;

  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if year_status <> 'DRAFT' then raise exception 'ACADEMIC_YEAR_NOT_DRAFT'; end if;
  if exists (select 1 from public.academic_years other
             where other.school_id = school_id
               and other.status = 'OPEN'
               and other.id <> p_academic_year_id) then
    raise exception 'ANOTHER_ACADEMIC_YEAR_ALREADY_OPEN';
  end if;
  if not (select private.has_permission('academic_year.manage', school_id)) then
    raise exception 'FORBIDDEN';
  end if;

  command_state := private.begin_command('open_academic_year', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  update public.academic_years set status = 'OPEN' where id = p_academic_year_id;

  insert into public.audit_events(school_id, actor_auth_user_id, action, entity_type, entity_id, after_data)
  values(school_id, actor, 'OPEN_ACADEMIC_YEAR', 'academic_year', p_academic_year_id,
         jsonb_build_object('status','OPEN','starts_on',year_start,'ends_on',year_end));

  result := jsonb_build_object('academic_year_id',p_academic_year_id,'status','OPEN');
  perform private.complete_command('open_academic_year', school_id, p_idempotency_key, result);
  return result;
end;
$$;

revoke all on function public.open_academic_year(uuid,text,text) from public;
grant execute on function public.open_academic_year(uuid,text,text) to authenticated;

-- Closing a year must end every active temporal participation that belongs to it.
create or replace function public.close_academic_year(
  p_academic_year_id uuid,
  p_close_on date default current_date,
  p_reason text default null,
  p_idempotency_key text default null,
  p_request_hash text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  school_id uuid;
  year_status public.academic_year_status;
  year_start date;
  year_end date;
  open_assessments integer;
  pending_enrollments integer;
  active_enrollments integer;
  future_placements integer;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status, ay.starts_on, ay.ends_on
    into school_id, year_status, year_start, year_end
  from public.academic_years ay where ay.id = p_academic_year_id for update;
  if school_id is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if not (select private.has_permission('academic_year.close', school_id)) then raise exception 'FORBIDDEN'; end if;
  if year_status <> 'OPEN' then raise exception 'ACADEMIC_YEAR_NOT_OPEN'; end if;
  if p_close_on < year_start or p_close_on > year_end then raise exception 'INVALID_CLOSE_DATE'; end if;
  if p_close_on < year_end and (p_reason is null or length(trim(p_reason)) < 5) then raise exception 'EARLY_CLOSE_REQUIRES_REASON'; end if;

  command_state := private.begin_command('close_academic_year', school_id, p_idempotency_key, p_request_hash);
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  select count(*) into open_assessments
  from public.assessments a join public.course_offerings co on co.id=a.course_offering_id
  where co.academic_year_id=p_academic_year_id and a.status='OPEN';
  if open_assessments > 0 then raise exception 'OPEN_ASSESSMENTS_REMAIN'; end if;

  if exists (select 1 from public.assessment_periods ap
             where ap.academic_year_id=p_academic_year_id and ap.active and ap.status <> 'CLOSED') then
    raise exception 'OPEN_ASSESSMENT_PERIODS_REMAIN';
  end if;

  select count(*) into pending_enrollments
  from public.student_enrollments e
  where e.academic_year_id=p_academic_year_id and e.status='PENDING';
  if pending_enrollments > 0 then raise exception 'PENDING_ENROLLMENTS_REMAIN'; end if;

  select count(*) into future_placements
  from public.class_placements cp
  join public.student_enrollments e on e.id=cp.enrollment_id
  where e.academic_year_id=p_academic_year_id
    and cp.status='ACTIVE'
    and cp.starts_on > p_close_on;
  if future_placements > 0 then raise exception 'FUTURE_CLASS_PLACEMENTS_REMAIN'; end if;

  select count(*) into active_enrollments
  from public.student_enrollments e
  where e.academic_year_id=p_academic_year_id and e.status in ('ACTIVE','TRANSFERRED_IN');

  update public.student_enrollments
     set status='COMPLETED', exited_on=p_close_on,
         exit_reason=coalesce(nullif(trim(p_reason),''),'ACADEMIC_YEAR_COMPLETED')
   where academic_year_id=p_academic_year_id and status in ('ACTIVE','TRANSFERRED_IN');

  update public.class_placements cp
     set status='ENDED', ends_on=p_close_on
   where cp.status='ACTIVE'
     and cp.starts_on <= p_close_on
     and cp.enrollment_id in (select e.id from public.student_enrollments e where e.academic_year_id=p_academic_year_id);

  update public.student_course_participations scp
     set status='ENDED', ends_on=p_close_on
   where scp.status='ACTIVE'
     and scp.starts_on <= p_close_on
     and scp.course_offering_id in (select co.id from public.course_offerings co where co.academic_year_id=p_academic_year_id);

  update public.academic_years
     set status='CLOSED', closed_at=now(), closed_by=actor
   where id=p_academic_year_id;

  insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,reason,after_data)
  values(school_id,actor,'CLOSE_ACADEMIC_YEAR','academic_year',p_academic_year_id,p_reason,
         jsonb_build_object('status','CLOSED','close_on',p_close_on,'completed_enrollments',active_enrollments));

  result := jsonb_build_object('academic_year_id',p_academic_year_id,'status','CLOSED',
                               'close_on',p_close_on,'completed_enrollments',active_enrollments);
  perform private.complete_command('close_academic_year',school_id,p_idempotency_key,result);
  return result;
end;
$$;

revoke all on function public.close_academic_year(uuid,date,text,text,text) from public;
grant execute on function public.close_academic_year(uuid,date,text,text,text) to authenticated;

-- A final result can only consume the exact three published trimester results
-- belonging to the same offering/year/student. The frequency calculation
-- must be chronologically T1/T2/T3 rather than merely any three periods.
comment on function public.calculate_frequency_result(uuid,uuid,uuid,uuid,uuid,text,text) is
  'Calculates MFD from exactly three published trimester results. The supplied result IDs must represent three distinct assessment periods in the same academic context.';
