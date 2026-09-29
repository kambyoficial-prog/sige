-- F8 reporting read models (source mirror of applied migration 20260929273000)
drop view if exists public.report_student_demographics;
create view public.report_student_demographics with(security_invoker=true) as
select s.school_id,p.gender,count(*)::bigint student_count from public.students s join public.people p on p.id=s.person_id group by s.school_id,p.gender;
drop view if exists public.report_enrollment_status;
create view public.report_enrollment_status with(security_invoker=true) as
select se.academic_year_id,ay.school_id,se.status,count(*)::bigint enrollment_count from public.student_enrollments se join public.academic_years ay on ay.id=se.academic_year_id group by se.academic_year_id,ay.school_id,se.status;
drop view if exists public.report_enrollment_grade;
create view public.report_enrollment_grade with(security_invoker=true) as
select se.academic_year_id,ay.school_id,gl.id grade_level_id,gl.code grade_code,gl.name grade_name,count(*)::bigint enrollment_count from public.student_enrollments se join public.academic_years ay on ay.id=se.academic_year_id join public.grade_levels gl on gl.id=se.grade_level_id group by se.academic_year_id,ay.school_id,gl.id,gl.code,gl.name;
drop view if exists public.report_class_capacity;
create view public.report_class_capacity with(security_invoker=true) as
select cg.academic_year_id,cg.school_id,cg.id class_group_id,cg.code,cg.name,cg.capacity,count(cp.id)::bigint placed_count,greatest(cg.capacity-count(cp.id),0)::bigint available_seats from public.class_groups cg left join public.class_placements cp on cp.class_group_id=cg.id and cp.status='ACTIVE' group by cg.academic_year_id,cg.school_id,cg.id,cg.code,cg.name,cg.capacity;
drop view if exists public.report_finance_summary;
create view public.report_finance_summary with(security_invoker=true) as
select c.academic_year_id,c.school_id,coalesce(sum(case when c.status in ('CANCELLED','WAIVED') then 0 else private.charge_effective_amount(c.id) end),0) charged_amount,coalesce((select sum(case when p.status='CONFIRMED' then pa.amount else 0 end) from public.payment_allocations pa join public.payments p on p.id=pa.payment_id join public.charges c2 on c2.id=pa.charge_id where c2.academic_year_id=c.academic_year_id and c2.school_id=c.school_id),0) paid_amount from public.charges c group by c.academic_year_id,c.school_id;
drop view if exists public.report_academic_outcomes;
create view public.report_academic_outcomes with(security_invoker=true) as
select ar.academic_year_id,ar.school_id,ar.result_type,count(*)::bigint result_count,count(*) filter(where ar.display_value>=10)::bigint approved_count,count(*) filter(where ar.display_value<10)::bigint failed_count,round(avg(ar.value),2) average_value from public.academic_results ar where ar.status='PUBLISHED' group by ar.academic_year_id,ar.school_id,ar.result_type;
grant select on public.report_student_demographics,public.report_enrollment_status,public.report_enrollment_grade,public.report_class_capacity,public.report_finance_summary,public.report_academic_outcomes to authenticated;
drop view if exists public.report_enrollment_exits;
create view public.report_enrollment_exits with(security_invoker=true) as select se.academic_year_id,ay.school_id,se.status,se.exit_reason,count(*)::bigint event_count from public.student_enrollments se join public.academic_years ay on ay.id=se.academic_year_id where se.exited_on is not null or se.status::text not in ('ACTIVE','ENROLLED') group by se.academic_year_id,ay.school_id,se.status,se.exit_reason;
drop view if exists public.report_class_transfers;
create view public.report_class_transfers with(security_invoker=true) as select cg.academic_year_id,cg.school_id,cp.reason,count(*)::bigint transfer_count from public.class_placements cp join public.class_groups cg on cg.id=cp.class_group_id where cp.reason is not null and cp.reason ilike '%transfer%' group by cg.academic_year_id,cg.school_id,cp.reason;
grant select on public.report_enrollment_exits,public.report_class_transfers to authenticated;