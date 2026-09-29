-- SIGE 0026 — academic period/year temporal locking and historical navigation

create type public.assessment_period_status as enum ('OPEN','CLOSED');

alter table public.assessment_periods
  add column if not exists status public.assessment_period_status not null default 'OPEN',
  add column if not exists closed_at timestamptz,
  add column if not exists closed_by uuid references auth.users(id) on delete set null;

update public.assessment_periods
set status = case when active then 'OPEN'::public.assessment_period_status else 'CLOSED'::public.assessment_period_status end
where status is null;

alter table public.assessment_periods
  add constraint assessment_periods_status_timestamps_ck
  check (status <> 'CLOSED' or closed_at is not null);

create index if not exists assessment_periods_history_idx
  on public.assessment_periods (academic_year_id, ordinal, status);

create or replace function public.close_assessment_period(
  p_assessment_period_id uuid,
  p_close_on date default current_date,
  p_reason text default null,
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
  academic_year_id uuid;
  year_status public.academic_year_status;
  period_status public.assessment_period_status;
  starts_on date;
  ends_on date;
  open_assessments integer;
  result jsonb;
  command_state jsonb;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select ay.school_id, ay.status, ap.academic_year_id, ap.status, ay.starts_on, ay.ends_on
    into school_id, year_status, academic_year_id, period_status, starts_on, ends_on
  from public.assessment_periods ap
  join public.academic_years ay on ay.id = ap.academic_year_id
  where ap.id = p_assessment_period_id
  for update of ap, ay;

  if school_id is null then raise exception 'ASSESSMENT_PERIOD_NOT_FOUND'; end if;
  if year_status <> 'OPEN' then raise exception 'ACADEMIC_YEAR_NOT_OPEN'; end if;
  if period_status <> 'OPEN' then raise exception 'ASSESSMENT_PERIOD_ALREADY_CLOSED'; end if;
  if p_close_on < starts_on or p_close_on > ends_on then raise exception 'INVALID_CLOSE_DATE'; end if;
  if not (select private.has_permission('assessment.manage', school_id)) then raise exception 'FORBIDDEN'; end if;

  select count(*)
    into open_assessments
  from public.assessments a
  join public.course_offerings co on co.id = a.course_offering_id
  where a.assessment_period_id = p_assessment_period_id
    and co.academic_year_id = academic_year_id
    and a.status = 'OPEN';

  if open_assessments > 0 then raise exception 'OPEN_ASSESSMENTS_REMAIN'; end if;

  command_state := private.begin_command(
    'close_assessment_period', school_id, p_idempotency_key, p_request_hash
  );
  if coalesce((command_state->>'replayed')::boolean, false) then return command_state->'result'; end if;

  update public.assessment_periods
  set status='CLOSED', active=false, closed_at=now(), closed_by=actor
  where id=p_assessment_period_id;

  result := jsonb_build_object(
    'assessment_period_id',p_assessment_period_id,
    'academic_year_id',academic_year_id,
    'status','CLOSED',
    'close_on',p_close_on
  );

  insert into public.audit_events(
    school_id,actor_auth_user_id,action,entity_type,entity_id,reason,after_data
  )
  values(
    school_id,actor,'CLOSE_ASSESSMENT_PERIOD','assessment_period',
    p_assessment_period_id,p_reason,result
  );

  perform private.complete_command(
    'close_assessment_period',school_id,p_idempotency_key,result
  );
  return result;
end;
$$;

revoke all on function public.close_assessment_period(uuid,date,text,text,text) from public;
grant execute on function public.close_assessment_period(uuid,date,text,text,text) to authenticated;

-- The database is the final guard: ordinary mutations must not alter
-- records belonging to a closed academic year. Explicit correction workflows
-- can later be granted their own command and audit trail.
create or replace function private.assert_academic_year_mutable(p_academic_year_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.academic_year_status;
begin
  select status into s
  from public.academic_years
  where id=p_academic_year_id;

  if s is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
  if s='CLOSED' then raise exception 'ACADEMIC_YEAR_CLOSED'; end if;
end;
$$;

create or replace function private.guard_closed_year_assessments()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  year_id uuid;
begin
  if tg_op='DELETE' then
    select co.academic_year_id into year_id
    from public.assessments a
    join public.course_offerings co on co.id=a.course_offering_id
    where a.id=old.id;
  else
    select co.academic_year_id into year_id
    from public.course_offerings co
    where co.id=new.course_offering_id;
  end if;
  perform private.assert_academic_year_mutable(year_id);
  return coalesce(new,old);
end;
$$;

drop trigger if exists trg_guard_closed_year_assessments on public.assessments;
create trigger trg_guard_closed_year_assessments
before insert or update or delete on public.assessments
for each row execute function private.guard_closed_year_assessments();

create or replace function private.guard_closed_year_assessment_results()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  year_id uuid;
begin
  select co.academic_year_id into year_id
  from public.assessments a
  join public.course_offerings co on co.id=a.course_offering_id
  where a.id=coalesce(new.assessment_id,old.assessment_id);
  perform private.assert_academic_year_mutable(year_id);
  return coalesce(new,old);
end;
$$;

drop trigger if exists trg_guard_closed_year_assessment_results on public.assessment_results;
create trigger trg_guard_closed_year_assessment_results
before insert or update or delete on public.assessment_results
for each row execute function private.guard_closed_year_assessment_results();

create or replace function private.guard_closed_year_academic_results()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform private.assert_academic_year_mutable(coalesce(new.academic_year_id,old.academic_year_id));
  return coalesce(new,old);
end;
$$;

drop trigger if exists trg_guard_closed_year_academic_results on public.academic_results;
create trigger trg_guard_closed_year_academic_results
before insert or update or delete on public.academic_results
for each row execute function private.guard_closed_year_academic_results();

-- Historical read models. They expose the whole timeline without reopening it.
create or replace view public.academic_year_history as
select
  ay.id,
  ay.school_id,
  ay.label,
  ay.starts_on,
  ay.ends_on,
  ay.status,
  ay.closed_at,
  ay.closed_by
from public.academic_years ay;

create or replace view public.assessment_period_history as
select
  ap.id,
  ap.academic_year_id,
  ap.code,
  ap.name,
  ap.ordinal,
  ap.starts_on,
  ap.ends_on,
  ap.status,
  ap.closed_at,
  ap.closed_by
from public.assessment_periods ap;

revoke all on public.academic_year_history from public;
grant select on public.academic_year_history to authenticated;
revoke all on public.assessment_period_history from public;
grant select on public.assessment_period_history to authenticated;
