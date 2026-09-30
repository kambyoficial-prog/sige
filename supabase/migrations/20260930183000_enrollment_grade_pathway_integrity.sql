-- SIGE — enrollment/read-model alignment for grade and second-cycle pathway
-- Mirrors the live integrity boundary and exposes pathway context to the UI.

drop function if exists public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,text,text);

create or replace function public.enroll_student(
  p_student_id uuid,p_academic_year_id uuid,p_grade_level_id uuid,
  p_entry_type public.enrollment_entry_type default 'INITIAL',
  p_enrolled_on date default current_date,p_pathway_id uuid default null,
  p_idempotency_key text default null,p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid:=(select auth.uid()); student_school uuid; year_school uuid;
year_status public.academic_year_status; year_start date; year_end date; grade_cycle uuid;
enrollment_id uuid; enrollment_sequence integer; pathway_school uuid; pathway_cycle uuid;
result jsonb; command_state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 select s.school_id into student_school from public.students s where s.id=p_student_id for update;
 if student_school is null then raise exception 'STUDENT_NOT_FOUND'; end if;
 select ay.school_id,ay.status,ay.starts_on,ay.ends_on into year_school,year_status,year_start,year_end
 from public.academic_years ay where ay.id=p_academic_year_id for share;
 if year_school is null then raise exception 'ACADEMIC_YEAR_NOT_FOUND'; end if;
 if student_school<>year_school then raise exception 'SCHOOL_CONTEXT_MISMATCH'; end if;
 if year_status<>'OPEN' then raise exception 'ACADEMIC_YEAR_NOT_OPEN'; end if;
 if p_enrolled_on<year_start or p_enrolled_on>year_end then raise exception 'ENROLLMENT_DATE_OUTSIDE_ACADEMIC_YEAR'; end if;
 if not (select private.has_permission('enrollment.manage',student_school)) then raise exception 'FORBIDDEN'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 select gl.academic_cycle_id into grade_cycle from public.grade_levels gl where gl.id=p_grade_level_id and gl.active;
 if grade_cycle is null then raise exception 'GRADE_LEVEL_NOT_FOUND'; end if;
 if exists(select 1 from public.academic_cycles ac where ac.id=grade_cycle and ac.code='C2') then
   if p_pathway_id is null then raise exception 'PATHWAY_REQUIRED_FOR_SECOND_CYCLE'; end if;
   select ap.school_id,ap.academic_cycle_id into pathway_school,pathway_cycle from public.academic_pathways ap where ap.id=p_pathway_id and ap.active;
   if pathway_cycle is null then raise exception 'PATHWAY_NOT_FOUND'; end if;
   if pathway_cycle<>grade_cycle then raise exception 'PATHWAY_CONTEXT_INVALID'; end if;
   if pathway_school is not null and pathway_school<>student_school then raise exception 'PATHWAY_SCHOOL_MISMATCH'; end if;
 elsif p_pathway_id is not null then raise exception 'PATHWAY_NOT_ALLOWED_FOR_FIRST_CYCLE'; end if;
 command_state:=private.begin_command('enroll_student',student_school,p_idempotency_key,p_request_hash);
 if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
 if exists(select 1 from public.student_enrollments e where e.student_id=p_student_id and e.academic_year_id=p_academic_year_id and e.status in ('PENDING','ACTIVE','TRANSFERRED_IN') and e.enrolled_on<=p_enrolled_on and (e.exited_on is null or e.exited_on>=p_enrolled_on)) then raise exception 'ACTIVE_ENROLLMENT_ALREADY_EXISTS'; end if;
 select coalesce(max(e.enrollment_sequence),0)+1 into enrollment_sequence from public.student_enrollments e where e.student_id=p_student_id and e.academic_year_id=p_academic_year_id;
 insert into public.student_enrollments(student_id,academic_year_id,grade_level_id,status,entry_type,enrolled_on,enrollment_sequence)
 values(p_student_id,p_academic_year_id,p_grade_level_id,'ACTIVE',p_entry_type,p_enrolled_on,enrollment_sequence) returning id into enrollment_id;
 if p_pathway_id is not null then
   insert into public.student_pathway_selections(student_id,source_cycle_id,target_cycle_id,academic_year_id,pathway_id,status,selected_by,confirmed_at,confirmed_by)
   values(p_student_id,grade_cycle,grade_cycle,p_academic_year_id,p_pathway_id,'CONFIRMED',actor,now(),actor)
   on conflict(student_id,academic_year_id,target_cycle_id) do update set pathway_id=excluded.pathway_id,status='CONFIRMED',selected_at=now(),selected_by=actor,confirmed_at=now(),confirmed_by=actor,cancelled_at=null,cancelled_by=null,reason=null;
 end if;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,after_data)
 values(student_school,actor,'ENROLL_STUDENT','student_enrollment',enrollment_id,jsonb_build_object('student_id',p_student_id,'academic_year_id',p_academic_year_id,'grade_level_id',p_grade_level_id,'pathway_id',p_pathway_id,'entry_type',p_entry_type,'enrolled_on',p_enrolled_on,'enrollment_sequence',enrollment_sequence));
 result:=jsonb_build_object('enrollment_id',enrollment_id,'student_id',p_student_id,'academic_year_id',p_academic_year_id,'grade_level_id',p_grade_level_id,'pathway_id',p_pathway_id,'enrollment_sequence',enrollment_sequence,'status','ACTIVE');
 perform private.complete_command('enroll_student',student_school,p_idempotency_key,result); return result;
end $$;
revoke all on function public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,uuid,text,text) from public;
grant execute on function public.enroll_student(uuid,uuid,uuid,public.enrollment_entry_type,date,uuid,text,text) to authenticated;

create or replace function public.place_student_in_class(
  p_enrollment_id uuid,p_class_group_id uuid,p_starts_on date default current_date,p_ends_on date default null,
  p_reason text default null,p_idempotency_key text default null,p_request_hash text default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare actor uuid:=(select auth.uid()); enrollment_school uuid; enrollment_year uuid; enrollment_grade uuid;
enrollment_status public.enrollment_status; enrollment_pathway uuid; class_school uuid; class_year uuid; class_grade uuid;
class_pathway uuid; class_status public.class_group_status; year_start date; year_end date; capacity integer; occupied integer;
placement_id uuid; result jsonb; command_state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 select s.school_id,e.academic_year_id,e.grade_level_id,e.status,
   (select sps.pathway_id from public.student_pathway_selections sps where sps.student_id=e.student_id and sps.academic_year_id=e.academic_year_id and sps.target_cycle_id=(select gl.academic_cycle_id from public.grade_levels gl where gl.id=e.grade_level_id) and sps.status in ('SELECTED','CONFIRMED') order by sps.created_at desc limit 1)
 into enrollment_school,enrollment_year,enrollment_grade,enrollment_status,enrollment_pathway
 from public.student_enrollments e join public.students s on s.id=e.student_id where e.id=p_enrollment_id for update;
 if enrollment_school is null then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
 if enrollment_status not in ('ACTIVE','TRANSFERRED_IN') then raise exception 'ENROLLMENT_NOT_PLACABLE'; end if;
 select cg.school_id,cg.academic_year_id,cg.grade_level_id,cg.pathway_id,cg.status,cg.capacity into class_school,class_year,class_grade,class_pathway,class_status,capacity from public.class_groups cg where cg.id=p_class_group_id for update;
 if class_school is null then raise exception 'CLASS_GROUP_NOT_FOUND'; end if;
 if enrollment_school<>class_school or enrollment_year<>class_year or enrollment_grade<>class_grade then raise exception 'CLASS_CONTEXT_MISMATCH'; end if;
 if class_pathway is not null and enrollment_pathway is distinct from class_pathway then raise exception 'CLASS_PATHWAY_MISMATCH'; end if;
 if class_status not in ('OPEN','ACTIVE') then raise exception 'CLASS_GROUP_NOT_OPEN'; end if;
 select ay.starts_on,ay.ends_on into year_start,year_end from public.academic_years ay where ay.id=enrollment_year;
 if p_starts_on<year_start or p_starts_on>year_end or (p_ends_on is not null and (p_ends_on<p_starts_on or p_ends_on>year_end)) then raise exception 'PLACEMENT_DATE_OUTSIDE_ACADEMIC_YEAR'; end if;
 if not (select private.has_permission('enrollment.manage',enrollment_school)) then raise exception 'FORBIDDEN'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 command_state:=private.begin_command('place_student_in_class',enrollment_school,p_idempotency_key,p_request_hash);
 if coalesce((command_state->>'replayed')::boolean,false) then return command_state->'result'; end if;
 select count(*)::integer into occupied from public.class_placements cp where cp.class_group_id=p_class_group_id and cp.status='ACTIVE' and daterange(cp.starts_on,coalesce(cp.ends_on+1,'9999-12-31'::date),'[)') && daterange(p_starts_on,coalesce(p_ends_on+1,'9999-12-31'::date),'[)');
 if capacity is not null and occupied>=capacity then raise exception 'CLASS_CAPACITY_REACHED'; end if;
 insert into public.class_placements(enrollment_id,class_group_id,starts_on,ends_on,status,reason) values(p_enrollment_id,p_class_group_id,p_starts_on,p_ends_on,'ACTIVE',p_reason) returning id into placement_id;
 insert into public.audit_events(school_id,actor_auth_user_id,action,entity_type,entity_id,reason,after_data) values(enrollment_school,actor,'PLACE_STUDENT_IN_CLASS','class_placement',placement_id,p_reason,jsonb_build_object('enrollment_id',p_enrollment_id,'class_group_id',p_class_group_id,'starts_on',p_starts_on,'ends_on',p_ends_on));
 result:=jsonb_build_object('placement_id',placement_id,'enrollment_id',p_enrollment_id,'class_group_id',p_class_group_id,'status','ACTIVE');
 perform private.complete_command('place_student_in_class',enrollment_school,p_idempotency_key,result); return result;
end $$;
revoke all on function public.place_student_in_class(uuid,uuid,date,date,text,text,text) from public;
grant execute on function public.place_student_in_class(uuid,uuid,date,date,text,text,text) to authenticated;

create or replace view public.enrollment_directory
with (security_invoker=true) as
select e.id,s.school_id,e.student_id,s.school_number,p.full_name as student_name,e.academic_year_id,ay.label as academic_year_label,
 e.grade_level_id,gl.name as grade_level_name,e.status,e.entry_type,e.enrolled_on,e.exited_on,e.exit_reason,e.enrollment_sequence,
 (select sps.pathway_id from public.student_pathway_selections sps
  where sps.student_id=e.student_id and sps.academic_year_id=e.academic_year_id
    and sps.target_cycle_id=gl.academic_cycle_id and sps.status in ('SELECTED','CONFIRMED')
  order by sps.created_at desc limit 1) as pathway_id,
 (select ap.name from public.academic_pathways ap
   where ap.id = (select sps.pathway_id from public.student_pathway_selections sps
     where sps.student_id=e.student_id and sps.academic_year_id=e.academic_year_id
       and sps.target_cycle_id=gl.academic_cycle_id and sps.status in ('SELECTED','CONFIRMED')
     order by sps.created_at desc limit 1)
 ) as pathway_name,
 placement.class_group_id,coalesce(cg.name,cg.section_code) as class_name
from public.student_enrollments e join public.students s on s.id=e.student_id join public.people p on p.id=s.person_id
join public.academic_years ay on ay.id=e.academic_year_id join public.grade_levels gl on gl.id=e.grade_level_id
left join lateral (select cp.class_group_id from public.class_placements cp where cp.enrollment_id=e.id and cp.status='ACTIVE' order by cp.starts_on desc limit 1) placement on true
left join public.class_groups cg on cg.id=placement.class_group_id;

create or replace view public.class_group_directory
with (security_invoker=true) as
select cg.id,cg.school_id,cg.academic_year_id,ay.label as academic_year_label,cg.grade_level_id,gl.name as grade_level_name,
 ac.name as academic_cycle_name,el.name as education_level_name,cg.section_code,cg.name,cg.pathway_id,cg.status,cg.shift,cg.capacity,
 coalesce((select count(*)::integer from public.class_placements cp where cp.class_group_id=cg.id and cp.status='ACTIVE'),0) as student_count,
 leadership.teacher_id as director_teacher_id,director_person.full_name as director_teacher_name
from public.class_groups cg join public.academic_years ay on ay.id=cg.academic_year_id join public.grade_levels gl on gl.id=cg.grade_level_id
join public.academic_cycles ac on ac.id=gl.academic_cycle_id join public.education_levels el on el.id=ac.education_level_id
left join lateral (select cgl.teacher_id from public.class_group_leadership cgl where cgl.class_group_id=cg.id and cgl.active and (cgl.ends_on is null or cgl.ends_on>=current_date) and cgl.starts_on<=current_date order by cgl.starts_on desc limit 1) leadership on true
left join public.teachers director_teacher on director_teacher.id=leadership.teacher_id
left join public.people director_person on director_person.id=director_teacher.person_id;

grant select on public.enrollment_directory,public.class_group_directory to authenticated;
