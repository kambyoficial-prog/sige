-- SIGE DEMO fixture: pedagogical structure, timetable and gradebook.
-- Synthetic homologation data only; not the school's official curriculum.

do $$
declare
  school uuid := '27bf14b8-0d53-4a6e-80cc-6fb2e3164bbb';
  year_id uuid := '4a200342-cf70-446a-a13b-941f9f8f6bfc';
  g7 uuid := 'b747ceed-c842-45be-95d5-e9eca5bf69e5';
  g8 uuid := '772f8342-26f2-401a-a139-e0f53fe85597';
  g9 uuid := 'a8b5bd20-66b8-4fed-ba6d-6ff783ed9e0a';
  rule_id uuid := 'bedab84a-b3d8-40bc-ab09-970cd1c34a82';
  t1 uuid;
  r record;
  teacher uuid;
  period_id uuid;
  room_id uuid;
  day smallint;
  v_period_ordinal integer;
begin
  update public.academic_years
  set grade_rule_version_id=rule_id
  where id=year_id and grade_rule_version_id is null;

  insert into public.subjects(school_id,code,name,short_name,active) values
    (school,'POR','Língua Portuguesa','Português',true),
    (school,'MAT','Matemática','Matemática',true),
    (school,'ING','Inglês','Inglês',true),
    (school,'HIS','História','História',true),
    (school,'GEO','Geografia','Geografia',true),
    (school,'BIO','Biologia','Biologia',true),
    (school,'FIS','Física','Física',true),
    (school,'QUI','Química','Química',true)
  on conflict(school_id,code) do update
    set name=excluded.name,short_name=excluded.short_name,active=true;

  insert into public.curriculum_subjects
    (school_id,academic_year_id,grade_level_id,subject_id,weekly_periods,mandatory,active,selection_mode,ordinal)
  select school,year_id,g.id,
         s.id,
         case s.code when 'POR' then 4 when 'MAT' then 4 when 'ING' then 3 else 2 end,
         true,true,'REQUIRED',row_number() over(order by s.code)::int
  from public.grade_levels g cross join public.subjects s
  where g.id in(g7,g8,g9) and s.school_id=school
    and not exists(select 1 from public.curriculum_subjects x
                   where x.academic_year_id=year_id and x.grade_level_id=g.id
                     and x.subject_id=s.id and x.pathway_id is null);

  insert into public.class_groups
    (school_id,academic_year_id,grade_level_id,section_code,name,status,capacity,shift)
  select school,year_id,x.grade_id,'A',x.name,'OPEN',35,'MORNING'
  from(values(g7,'7.ª Classe A'),(g8,'8.ª Classe A'),(g9,'9.ª Classe A')) x(grade_id,name)
  where not exists(select 1 from public.class_groups cg
                   where cg.academic_year_id=year_id and cg.grade_level_id=x.grade_id
                     and lower(cg.section_code)='a' and cg.pathway_id is null);

  update public.class_groups set status='OPEN',capacity=35,shift='MORNING'
  where academic_year_id=year_id and grade_level_id in(g7,g8,g9)
    and lower(section_code)='a' and pathway_id is null;

  insert into public.course_offerings
    (school_id,academic_year_id,class_group_id,subject_id,curriculum_subject_id,status)
  select school,year_id,cg.id,cs.subject_id,cs.id,'OPEN'
  from public.class_groups cg
  join public.curriculum_subjects cs
    on cs.academic_year_id=cg.academic_year_id
   and cs.grade_level_id=cg.grade_level_id
   and cs.pathway_id is null and cs.active
  where cg.academic_year_id=year_id and cg.school_id=school
    and not exists(select 1 from public.course_offerings co
                   where co.class_group_id=cg.id and co.subject_id=cs.subject_id);

  insert into public.people(full_name,first_name,last_name,gender,birth_date,phone,address)
  select * from(values
    ('Mário Cuamba','Mário','Cuamba','M','1977-04-08'::date,'842000004','Tete'),
    ('Teresa Sumbana','Teresa','Sumbana','F','1984-06-14'::date,'842000005','Tete'),
    ('Alberto Matusse','Alberto','Matusse','M','1979-11-19'::date,'842000006','Tete'),
    ('Amélia Bila','Amélia','Bila','F','1981-02-26'::date,'842000007','Tete'),
    ('Nelson Mavume','Nelson','Mavume','M','1986-09-11'::date,'842000008','Tete')
  ) x(full_name,first_name,last_name,gender,birth_date,phone,address)
  where not exists(select 1 from public.people p where p.full_name=x.full_name);

  insert into public.teachers(school_id,person_id,employee_code,status)
  select school,p.id,x.code,'ACTIVE'
  from(values
    ('Mário Cuamba','PROF-004'),('Teresa Sumbana','PROF-005'),
    ('Alberto Matusse','PROF-006'),('Amélia Bila','PROF-007'),('Nelson Mavume','PROF-008')
  ) x(full_name,code) join public.people p on p.full_name=x.full_name
  where not exists(select 1 from public.teachers t where t.school_id=school and t.employee_code=x.code);

  for r in select co.id,s.code from public.course_offerings co join public.subjects s on s.id=co.subject_id where co.academic_year_id=year_id loop
    select t.id into teacher from public.teachers t
    where t.school_id=school and t.employee_code=case r.code
      when 'POR' then 'PROF-001' when 'MAT' then 'PROF-002' when 'ING' then 'PROF-003'
      when 'HIS' then 'PROF-004' when 'GEO' then 'PROF-005' when 'BIO' then 'PROF-006'
      when 'FIS' then 'PROF-007' when 'QUI' then 'PROF-008' end;
    insert into public.teacher_assignments(teacher_id,course_offering_id,starts_on,ends_on,active)
    select teacher,r.id,'2026-01-01','2027-12-31',true
    where teacher is not null and not exists(
      select 1 from public.teacher_assignments ta
      where ta.teacher_id=teacher and ta.course_offering_id=r.id and ta.active);
  end loop;

  insert into public.class_placements(enrollment_id,class_group_id,starts_on,status)
  select e.id,cg.id,'2026-01-10','ACTIVE'
  from public.student_enrollments e
  join public.class_groups cg on cg.academic_year_id=e.academic_year_id
    and cg.grade_level_id=e.grade_level_id and cg.section_code='A' and cg.pathway_id is null
  where e.academic_year_id=year_id and e.status='ACTIVE'
    and not exists(select 1 from public.class_placements cp
                   where cp.enrollment_id=e.id and cp.status='ACTIVE');

  insert into public.student_course_participations(student_id,course_offering_id,starts_on,status)
  select e.student_id,co.id,'2026-01-10','ACTIVE'
  from public.student_enrollments e
  join public.class_placements cp on cp.enrollment_id=e.id and cp.status='ACTIVE'
  join public.course_offerings co on co.class_group_id=cp.class_group_id and co.status in('OPEN','ACTIVE')
  where e.academic_year_id=year_id
    and not exists(select 1 from public.student_course_participations p
                   where p.student_id=e.student_id and p.course_offering_id=co.id and p.status='ACTIVE');

  insert into public.rooms(school_id,code,name,capacity) values
    (school,'SALA-01','Sala 01',35),(school,'SALA-02','Sala 02',35),(school,'LAB-01','Laboratório 01',30)
  on conflict(school_id,code) do nothing;

  insert into public.schedule_periods(school_id,code,name,ordinal,starts_at,ends_at) values
    (school,'P1','1.º Período',1,'07:00','07:45'),(school,'P2','2.º Período',2,'07:50','08:35'),
    (school,'P3','3.º Período',3,'08:40','09:25'),(school,'P4','4.º Período',4,'09:40','10:25'),
    (school,'P5','5.º Período',5,'10:30','11:15'),(school,'P6','6.º Período',6,'11:20','12:05'),
    (school,'P7','7.º Período',7,'12:10','12:55'),(school,'P8','8.º Período',8,'13:00','13:45')
  on conflict(school_id,code) do nothing;

  for r in
    select co.id offering_id,co.class_group_id,ta.id assignment_id,ta.teacher_id,
           row_number() over(partition by co.class_group_id order by s.code)::int n,
           dense_rank() over(order by cg.grade_level_id)::int class_n
    from public.course_offerings co join public.subjects s on s.id=co.subject_id
    join public.class_groups cg on cg.id=co.class_group_id
    join public.teacher_assignments ta on ta.course_offering_id=co.id and ta.active
    where co.academic_year_id=year_id
  loop
    day=((r.class_n+r.n-2)%5)+1; v_period_ordinal=((r.n-1)%8)+1;
    select id into period_id from public.schedule_periods where school_id=school and ordinal=v_period_ordinal limit 1;
    select id into room_id from public.rooms where school_id=school order by code offset r.class_n-1 limit 1;
    insert into public.schedule_entries
      (school_id,academic_year_id,class_group_id,course_offering_id,teacher_assignment_id,teacher_id,room_id,period_id,day_of_week,valid_from,valid_until,status)
    select school,year_id,r.class_group_id,r.offering_id,r.assignment_id,r.teacher_id,room_id,period_id,day,'2026-01-01','2027-12-31','ACTIVE'
    where not exists(select 1 from public.schedule_entries se
                     where se.course_offering_id=r.offering_id and se.day_of_week=day
                       and se.period_id=period_id and se.valid_from='2026-01-01');
  end loop;

  insert into public.assessment_periods(academic_year_id,code,name,ordinal,starts_on,ends_on,active,status) values
    (year_id,'T1','1.º Trimestre',1,'2026-01-01','2026-05-31',true,'OPEN'),
    (year_id,'T2','2.º Trimestre',2,'2026-06-01','2026-08-31',true,'OPEN'),
    (year_id,'T3','3.º Trimestre',3,'2026-09-01','2027-12-31',true,'OPEN')
  on conflict(academic_year_id,code) do nothing;

  select id into t1 from public.assessment_periods where academic_year_id=year_id and code='T1';

  for r in select co.id offering_id from public.course_offerings co join public.class_groups cg on cg.id=co.class_group_id where cg.grade_level_id=g7 and co.academic_year_id=year_id loop
    insert into public.assessment_definitions
      (school_id,academic_year_id,course_offering_id,assessment_period_id,grade_rule_version_id,code,name,type,ordinal,required,counts_in_macs,max_score,active)
    select school,year_id,r.offering_id,t1,rule_id,x.code,x.name,x.type::public.assessment_type,x.ordinal,x.required,x.counts,20,true
    from(values
      ('AC1','Avaliação Contínua 1','ACS',1,false,true),('AC2','Avaliação Contínua 2','ACS',2,false,true),
      ('AC3','Avaliação Contínua 3','ACS',3,false,true),('AC4','Avaliação Contínua 4','ACS',4,false,true),
      ('AT','Avaliação do Trabalho','AT',5,true,false)
    ) x(code,name,type,ordinal,required,counts)
    where not exists(select 1 from public.assessment_definitions d
                     where d.course_offering_id=r.offering_id and d.assessment_period_id=t1 and d.code=x.code);

    insert into public.assessments(course_offering_id,assessment_period_id,type,title,assessment_date,max_score,status,definition_id)
    select d.course_offering_id,t1,d.type,d.name,'2026-04-15',20,'OPEN',d.id
    from public.assessment_definitions d
    where d.course_offering_id=r.offering_id and d.assessment_period_id=t1
      and not exists(select 1 from public.assessments a where a.definition_id=d.id);
  end loop;

  insert into public.assessment_results(assessment_id,student_id,raw_score,normalized_score,status,entered_at,published_at)
  select a.id,p.student_id,
         case d.code when 'AC1' then 15 when 'AC2' then 16 when 'AT' then 17 end,
         case d.code when 'AC1' then 15 when 'AC2' then 16 when 'AT' then 17 end,
         'PUBLISHED',now(),now()
  from public.assessments a join public.assessment_definitions d on d.id=a.definition_id
  join public.student_course_participations p on p.course_offering_id=a.course_offering_id and p.status='ACTIVE'
  where a.assessment_period_id=t1 and d.code in('AC1','AC2','AT')
    and not exists(select 1 from public.assessment_results ar where ar.assessment_id=a.id and ar.student_id=p.student_id);
end $$;