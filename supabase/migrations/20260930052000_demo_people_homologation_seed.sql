-- SIGE DEMO fixture: synthetic people and administrative lifecycle.
-- This is homologation data only; it must never be treated as real school data.

do $$
declare
  v_school uuid := '27bf14b8-0d53-4a6e-80cc-6fb2e3164bbb';
  v_year uuid := '4a200342-cf70-446a-a13b-941f9f8f6bfc';
  v_grade7 uuid := 'b747ceed-c842-45be-95d5-e9eca5bf69e5';
  v_grade8 uuid := '772f8342-26f2-401a-a139-e0f53fe85597';
  v_grade9 uuid := 'a8b5bd20-66b8-4fed-ba6d-6ff783ed9e0a';
begin
  insert into public.people (id,full_name,first_name,last_name,gender,birth_date,national_id,phone,address)
  values
    ('11111111-1111-4111-8111-111111111111','Anderson Tamele','Anderson','Tamele','M',date '2012-04-18','DEMO-BI-0001','841000001','Tete, Bairro Matundo'),
    ('11111111-1111-4111-8111-111111111112','Elisa Macamo','Elisa','Macamo','F',date '2012-09-02','DEMO-BI-0002','841000002','Tete, Bairro Chingodzi'),
    ('11111111-1111-4111-8111-111111111113','Mateus Cossa','Mateus','Cossa','M',date '2011-11-21','DEMO-BI-0003','841000003','Tete, Bairro Francisco Manyanga'),
    ('11111111-1111-4111-8111-111111111114','Nádia Mucavele','Nádia','Mucavele','F',date '2011-06-13','DEMO-BI-0004','841000004','Tete, Bairro Josina Machel'),
    ('11111111-1111-4111-8111-111111111115','Tomás Nhantumbo','Tomás','Nhantumbo','M',date '2010-02-27','DEMO-BI-0005','841000005','Tete, Bairro Degue'),
    ('11111111-1111-4111-8111-111111111116','Lúcia Manjate','Lúcia','Manjate','F',date '2010-12-09','DEMO-BI-0006','841000006','Tete, Bairro Samora Machel')
  on conflict (id) do nothing;

  insert into public.students (id,school_id,person_id,school_number,status,admission_date)
  values
    ('21111111-1111-4111-8111-111111111111',v_school,'11111111-1111-4111-8111-111111111111','2026-0001','ACTIVE',date '2026-01-10'),
    ('21111111-1111-4111-8111-111111111112',v_school,'11111111-1111-4111-8111-111111111112','2026-0002','ACTIVE',date '2026-01-11'),
    ('21111111-1111-4111-8111-111111111113',v_school,'11111111-1111-4111-8111-111111111113','2026-0003','ACTIVE',date '2026-01-12'),
    ('21111111-1111-4111-8111-111111111114',v_school,'11111111-1111-4111-8111-111111111114','2026-0004','ACTIVE',date '2026-01-13'),
    ('21111111-1111-4111-8111-111111111115',v_school,'11111111-1111-4111-8111-111111111115','2026-0005','ACTIVE',date '2026-01-14'),
    ('21111111-1111-4111-8111-111111111116',v_school,'11111111-1111-4111-8111-111111111116','2026-0006','ACTIVE',date '2026-01-15')
  on conflict (id) do nothing;

  insert into public.people (id,full_name,first_name,last_name,gender,birth_date,national_id,phone,address)
  values
    ('31111111-1111-4111-8111-111111111111','Joaquim Tamele','Joaquim','Tamele','M',date '1983-03-12','DEMO-G-0001','841100001','Tete, Bairro Matundo'),
    ('31111111-1111-4111-8111-111111111112','Rosa Macamo','Rosa','Macamo','F',date '1987-07-25','DEMO-G-0002','841100002','Tete, Bairro Chingodzi'),
    ('31111111-1111-4111-8111-111111111113','António Cossa','António','Cossa','M',date '1980-01-17','DEMO-G-0003','841100003','Tete, Bairro Francisco Manyanga'),
    ('31111111-1111-4111-8111-111111111114','Marta Mucavele','Marta','Mucavele','F',date '1985-05-09','DEMO-G-0004','841100004','Tete, Bairro Josina Machel'),
    ('31111111-1111-4111-8111-111111111115','Carlos Nhantumbo','Carlos','Nhantumbo','M',date '1979-10-30','DEMO-G-0005','841100005','Tete, Bairro Degue'),
    ('31111111-1111-4111-8111-111111111116','Helena Manjate','Helena','Manjate','F',date '1986-08-16','DEMO-G-0006','841100006','Tete, Bairro Samora Machel')
  on conflict (id) do nothing;

  insert into public.guardians (id,school_id,person_id,relationship,occupation,identity_number,address,phone)
  values
    ('41111111-1111-4111-8111-111111111111',v_school,'31111111-1111-4111-8111-111111111111','Pai','Técnico','DEMO-G-0001','Tete, Bairro Matundo','841100001'),
    ('41111111-1111-4111-8111-111111111112',v_school,'31111111-1111-4111-8111-111111111112','Mãe','Comerciante','DEMO-G-0002','Tete, Bairro Chingodzi','841100002'),
    ('41111111-1111-4111-8111-111111111113',v_school,'31111111-1111-4111-8111-111111111113','Pai','Funcionário','DEMO-G-0003','Tete, Bairro Francisco Manyanga','841100003'),
    ('41111111-1111-4111-8111-111111111114',v_school,'31111111-1111-4111-8111-111111111114','Mãe','Professora','DEMO-G-0004','Tete, Bairro Josina Machel','841100004'),
    ('41111111-1111-4111-8111-111111111115',v_school,'31111111-1111-4111-8111-111111111115','Pai','Motorista','DEMO-G-0005','Tete, Bairro Degue','841100005'),
    ('41111111-1111-4111-8111-111111111116',v_school,'31111111-1111-4111-8111-111111111116','Mãe','Enfermeira','DEMO-G-0006','Tete, Bairro Samora Machel','841100006')
  on conflict (id) do nothing;

  insert into public.student_guardians (student_id,guardian_id,relationship,is_primary,lives_with_student)
  values
    ('21111111-1111-4111-8111-111111111111','41111111-1111-4111-8111-111111111111','Pai',true,true),
    ('21111111-1111-4111-8111-111111111112','41111111-1111-4111-8111-111111111112','Mãe',true,true),
    ('21111111-1111-4111-8111-111111111113','41111111-1111-4111-8111-111111111113','Pai',true,false),
    ('21111111-1111-4111-8111-111111111114','41111111-1111-4111-8111-111111111114','Mãe',true,true),
    ('21111111-1111-4111-8111-111111111115','41111111-1111-4111-8111-111111111115','Pai',true,true),
    ('21111111-1111-4111-8111-111111111116','41111111-1111-4111-8111-111111111116','Mãe',true,true)
  on conflict do nothing;

  insert into public.people (id,full_name,first_name,last_name,gender,birth_date,phone,address)
  values
    ('51111111-1111-4111-8111-111111111111','Paulo Chivambo','Paulo','Chivambo','M',date '1978-02-10','842000001','Tete'),
    ('51111111-1111-4111-8111-111111111112','Celina Sitoe','Celina','Sitoe','F',date '1982-05-22','842000002','Tete'),
    ('51111111-1111-4111-8111-111111111113','Ernesto Balate','Ernesto','Balate','M',date '1975-09-03','842000003','Tete')
  on conflict (id) do nothing;

  insert into public.teachers (id,school_id,person_id,employee_code,status)
  values
    ('61111111-1111-4111-8111-111111111111',v_school,'51111111-1111-4111-8111-111111111111','PROF-001','ACTIVE'),
    ('61111111-1111-4111-8111-111111111112',v_school,'51111111-1111-4111-8111-111111111112','PROF-002','ACTIVE'),
    ('61111111-1111-4111-8111-111111111113',v_school,'51111111-1111-4111-8111-111111111113','PROF-003','ACTIVE')
  on conflict (id) do nothing;

  insert into public.student_enrollments
    (id,student_id,academic_year_id,grade_level_id,status,entry_type,enrolled_on,enrollment_sequence)
  values
    ('71111111-1111-4111-8111-111111111111','21111111-1111-4111-8111-111111111111',v_year,v_grade7,'ACTIVE','INITIAL',date '2026-01-10',1),
    ('71111111-1111-4111-8111-111111111112','21111111-1111-4111-8111-111111111112',v_year,v_grade7,'ACTIVE','INITIAL',date '2026-01-11',1),
    ('71111111-1111-4111-8111-111111111113','21111111-1111-4111-8111-111111111113',v_year,v_grade8,'ACTIVE','INITIAL',date '2026-01-12',1),
    ('71111111-1111-4111-8111-111111111114','21111111-1111-4111-8111-111111111114',v_year,v_grade8,'ACTIVE','TRANSFER_IN',date '2026-01-13',1),
    ('71111111-1111-4111-8111-111111111115','21111111-1111-4111-8111-111111111115',v_year,v_grade9,'ACTIVE','INITIAL',date '2026-01-14',1),
    ('71111111-1111-4111-8111-111111111116','21111111-1111-4111-8111-111111111116',v_year,v_grade9,'ACTIVE','INITIAL',date '2026-01-15',1)
  on conflict (id) do nothing;

  insert into public.student_registrations
    (id,student_id,enrollment_id,academic_year_id,registration_type,status,registered_on,confirmed_on)
  values
    ('81111111-1111-4111-8111-111111111111','21111111-1111-4111-8111-111111111111','71111111-1111-4111-8111-111111111111',v_year,'INITIAL','CONFIRMED',date '2026-01-10',date '2026-01-10'),
    ('81111111-1111-4111-8111-111111111112','21111111-1111-4111-8111-111111111112','71111111-1111-4111-8111-111111111112',v_year,'INITIAL','CONFIRMED',date '2026-01-11',date '2026-01-11'),
    ('81111111-1111-4111-8111-111111111113','21111111-1111-4111-8111-111111111113','71111111-1111-4111-8111-111111111113',v_year,'INITIAL','CONFIRMED',date '2026-01-12',date '2026-01-12'),
    ('81111111-1111-4111-8111-111111111114','21111111-1111-4111-8111-111111111114','71111111-1111-4111-8111-111111111114',v_year,'TRANSFER_IN','CONFIRMED',date '2026-01-13',date '2026-01-13'),
    ('81111111-1111-4111-8111-111111111115','21111111-1111-4111-8111-111111111115','71111111-1111-4111-8111-111111111115',v_year,'INITIAL','CONFIRMED',date '2026-01-14',date '2026-01-14'),
    ('81111111-1111-4111-8111-111111111116','21111111-1111-4111-8111-111111111116','71111111-1111-4111-8111-111111111116',v_year,'INITIAL','CONFIRMED',date '2026-01-15',date '2026-01-15')
  on conflict (id) do nothing;
end $$;
