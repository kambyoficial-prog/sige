-- SIGE: monthly tuition obligations and complete registration lifecycle.
alter table public.student_registrations drop constraint if exists student_registrations_status_ck;
alter table public.student_registrations add constraint student_registrations_status_ck check (status in ('DRAFT','PENDING','CONFIRMED','CANCELLED','WITHDRAWN','TRANSFERRED','COMPLETED'));

create or replace function public.generate_monthly_tuition_charges(
 p_student_id uuid,p_academic_year_id uuid,p_fee_type_id uuid,p_amount numeric,p_due_dates jsonb,
 p_idempotency_key text default null,p_request_hash text default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); school_id uuid; year_school uuid; item text; charge_id uuid; created_count integer:=0; result jsonb; state jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
 if p_amount<=0 then raise exception 'INVALID_TUITION_AMOUNT'; end if;
 if jsonb_typeof(p_due_dates)<>'array' or jsonb_array_length(p_due_dates)=0 then raise exception 'TUITION_DATES_REQUIRED'; end if;
 select s.school_id into school_id from public.students s where s.id=p_student_id and s.status='ACTIVE';
 select ay.school_id into year_school from public.academic_years ay where ay.id=p_academic_year_id;
 if school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
 if year_school is null or year_school<>school_id then raise exception 'CHARGE_YEAR_SCHOOL_MISMATCH'; end if;
 if not private.has_permission('finance.manage',school_id) then raise exception 'FORBIDDEN'; end if;
 if not exists(select 1 from public.fee_types ft where ft.id=p_fee_type_id and ft.school_id=school_id) then raise exception 'FEE_TYPE_NOT_FOUND'; end if;
 state:=private.begin_command('generate_monthly_tuition_charges',school_id,p_idempotency_key,p_request_hash);
 if coalesce((state->>'replayed')::boolean,false) then return state->'result'; end if;
 for item in select value from jsonb_array_elements_text(p_due_dates)
 loop
   if exists(select 1 from public.charges c where c.student_id=p_student_id and c.academic_year_id=p_academic_year_id and c.fee_type_id=p_fee_type_id and c.due_on=item::date and c.status<>'CANCELLED') then continue; end if;
   insert into public.charges(school_id,student_id,academic_year_id,fee_type_id,amount,due_on,description)
   values(school_id,p_student_id,p_academic_year_id,p_fee_type_id,p_amount,item::date,'Mensalidade')
   returning id into charge_id;
   created_count:=created_count+1;
 end loop;
 result:=jsonb_build_object('created_count',created_count);
 perform private.complete_command('generate_monthly_tuition_charges',school_id,p_idempotency_key,result);
 return result;
end; $$;
revoke all on function public.generate_monthly_tuition_charges(uuid,uuid,uuid,numeric,jsonb,text,text) from public;
grant execute on function public.generate_monthly_tuition_charges(uuid,uuid,uuid,numeric,jsonb,text,text) to authenticated;