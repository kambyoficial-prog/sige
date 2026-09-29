-- SIGE 0002 — Authorization model and RLS policies
-- RBAC is stored in the domain model; RLS is the database enforcement boundary.

insert into public.roles (code, name, description, system_role)
values
  ('DIRECTION', 'Direção', 'Acesso administrativo amplo dentro da escola.', true),
  ('SECRETARIAT', 'Secretaria', 'Operações de secretaria e cadastro escolar.', true),
  ('PEDAGOGICAL_DIRECTION', 'Direção Pedagógica', 'Supervisão pedagógica e homologação académica.', true),
  ('TEACHER', 'Professor', 'Operação limitada às ofertas/disciplines atribuídas.', true),
  ('FINANCE', 'Finanças', 'Operações financeiras e consulta escolar necessária.', true)
on conflict (code) do update
set name = excluded.name, description = excluded.description;

insert into public.permissions (code, name, description)
values
  ('school.read', 'Consultar escola', 'Consultar dados institucionais da escola.'),
  ('people.read', 'Consultar pessoas', 'Consultar pessoas ligadas à escola.'),
  ('people.write', 'Gerir pessoas', 'Criar e atualizar cadastros de pessoas.'),
  ('students.read', 'Consultar alunos', 'Consultar alunos e dados académicos básicos.'),
  ('students.write', 'Gerir alunos', 'Criar e atualizar cadastros de alunos.'),
  ('enrollment.read', 'Consultar matrículas', 'Consultar matrículas e histórico de vínculo escolar.'),
  ('enrollment.manage', 'Gerir matrículas', 'Criar, alterar, transferir, cancelar ou concluir matrículas.'),
  ('academic.read', 'Consultar estrutura académica', 'Consultar anos, classes, turmas, disciplinas e ofertas.'),
  ('academic.manage', 'Gerir estrutura académica', 'Gerir estrutura académica e alocações.'),
  ('academic.own.read', 'Consultar própria carga académica', 'Professor consulta apenas ofertas atribuídas.'),
  ('assessment.read', 'Consultar avaliações', 'Consultar avaliações e resultados.'),
  ('assessment.manage', 'Gerir avaliações', 'Criar, alterar e publicar avaliações.'),
  ('assessment.own.read', 'Consultar próprias avaliações', 'Professor consulta avaliações das próprias ofertas.'),
  ('assessment.own.enter', 'Lançar próprias avaliações', 'Professor lança resultados nas próprias ofertas.'),
  ('reports.read', 'Consultar relatórios', 'Consultar relatórios autorizados.'),
  ('administration.manage', 'Administrar acessos', 'Gerir contas, funções e permissões.'),
  ('finance.read', 'Consultar finanças', 'Consultar obrigações, pagamentos e saldos.'),
  ('finance.manage', 'Gerir finanças', 'Registar, ajustar e reverter operações financeiras.')
on conflict (code) do update
set name = excluded.name, description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on
  (r.code = 'DIRECTION' and p.code in (
    'school.read','people.read','people.write','students.read','students.write',
    'enrollment.read','enrollment.manage','academic.read','academic.manage',
    'assessment.read','assessment.manage','reports.read','administration.manage',
    'finance.read','finance.manage'
  ))
  or
  (r.code = 'SECRETARIAT' and p.code in (
    'school.read','people.read','people.write','students.read','students.write',
    'enrollment.read','enrollment.manage','academic.read','academic.manage',
    'reports.read'
  ))
  or
  (r.code = 'PEDAGOGICAL_DIRECTION' and p.code in (
    'school.read','people.read','students.read','enrollment.read','academic.read',
    'academic.manage','assessment.read','assessment.manage','reports.read'
  ))
  or
  (r.code = 'TEACHER' and p.code in (
    'school.read','students.read','academic.own.read',
    'assessment.own.read','assessment.own.enter'
  ))
  or
  (r.code = 'FINANCE' and p.code in (
    'school.read','students.read','people.read','finance.read',
    'finance.manage','reports.read'
  ))
on conflict do nothing;

create or replace function private.has_permission(
  permission_code text,
  target_school_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.app_accounts aa
    join public.account_roles ar
      on ar.account_id = aa.id
     and ar.starts_at <= now()
     and (ar.ends_at is null or ar.ends_at > now())
    join public.roles r on r.id = ar.role_id
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where aa.auth_user_id = (select auth.uid())
      and aa.status = 'ACTIVE'
      and p.code = permission_code
      and (target_school_id is null or aa.school_id = target_school_id)
  );
$$;

create or replace function private.person_in_school(
  person_uuid uuid,
  target_school_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1 from public.students s
    where s.person_id = person_uuid and s.school_id = target_school_id
  )
  or exists (
    select 1 from public.teachers t
    where t.person_id = person_uuid and t.school_id = target_school_id
  )
  or exists (
    select 1 from public.staff_members sm
    where sm.person_id = person_uuid and sm.school_id = target_school_id
  )
  or exists (
    select 1
    from public.guardians g
    join public.student_guardians sg on sg.guardian_id = g.id
    join public.students s on s.id = sg.student_id
    where g.person_id = person_uuid and s.school_id = target_school_id
  );
$$;

create or replace function private.teacher_for_offering(
  teacher_uuid uuid,
  offering_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.teacher_assignments ta
    where ta.teacher_id = teacher_uuid
      and ta.course_offering_id = offering_uuid
      and ta.active
      and ta.starts_on <= current_date
      and (ta.ends_on is null or ta.ends_on >= current_date)
  );
$$;

revoke all on function private.has_permission(text, uuid) from public;
revoke all on function private.person_in_school(uuid, uuid) from public;
revoke all on function private.teacher_for_offering(uuid, uuid) from public;
grant execute on function private.has_permission(text, uuid) to authenticated;
grant execute on function private.person_in_school(uuid, uuid) to authenticated;
grant execute on function private.teacher_for_offering(uuid, uuid) to authenticated;

-- The Data API should never expose these catalogs anonymously.
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Global/reference data.
create policy education_levels_read on public.education_levels
  for select to authenticated
  using ((select private.has_permission('academic.read')));

create policy roles_admin_read on public.roles
  for select to authenticated
  using ((select private.has_permission('administration.manage')));

create policy permissions_admin_read on public.permissions
  for select to authenticated
  using ((select private.has_permission('administration.manage')));

create policy role_permissions_admin_all on public.role_permissions
  for all to authenticated
  using ((select private.has_permission('administration.manage')))
  with check ((select private.has_permission('administration.manage')));

-- School-scoped records.
create policy schools_read on public.schools
  for select to authenticated
  using ((select private.has_permission('school.read', id)));

create policy schools_manage on public.schools
  for update to authenticated
  using ((select private.has_permission('administration.manage', id)))
  with check ((select private.has_permission('administration.manage', id)));

create policy academic_years_read on public.academic_years
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy academic_years_manage on public.academic_years
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy people_read on public.people
  for select to authenticated
  using (
    exists (
      select 1
      from public.students s
      where s.person_id = people.id
        and (select private.has_permission('people.read', s.school_id))
    )
    or exists (
      select 1
      from public.teachers t
      where t.person_id = people.id
        and (select private.has_permission('people.read', t.school_id))
    )
    or exists (
      select 1
      from public.staff_members sm
      where sm.person_id = people.id
        and (select private.has_permission('people.read', sm.school_id))
    )
    or exists (
      select 1
      from public.guardians g
      join public.student_guardians sg on sg.guardian_id = g.id
      join public.students s on s.id = sg.student_id
      where g.person_id = people.id
        and (select private.has_permission('people.read', s.school_id))
    )
  );

create policy people_write on public.people
  for insert to authenticated
  with check (
    (select private.has_permission('people.write'))
  );

create policy people_update on public.people
  for update to authenticated
  using ((select private.person_in_school(id, (
    select aa.school_id from public.app_accounts aa
    where aa.auth_user_id = (select auth.uid()) and aa.status = 'ACTIVE'
    limit 1
  ))) and (select private.has_permission('people.write')))
  with check ((select private.has_permission('people.write')));

create policy students_read on public.students
  for select to authenticated
  using ((select private.has_permission('students.read', school_id)));

create policy students_manage on public.students
  for all to authenticated
  using ((select private.has_permission('students.write', school_id)))
  with check ((select private.has_permission('students.write', school_id)));

create policy student_identifiers_all on public.student_identifiers
  for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_identifiers.student_id
        and (select private.has_permission('students.write', s.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_identifiers.student_id
        and (select private.has_permission('students.write', s.school_id))
    )
  );

create policy guardians_read on public.guardians
  for select to authenticated
  using (
    exists (
      select 1
      from public.student_guardians sg
      join public.students s on s.id = sg.student_id
      where sg.guardian_id = guardians.id
        and (select private.has_permission('people.read', s.school_id))
    )
  );

create policy guardians_manage on public.guardians
  for all to authenticated
  using (
    exists (
      select 1
      from public.student_guardians sg
      join public.students s on s.id = sg.student_id
      where sg.guardian_id = guardians.id
        and (select private.has_permission('people.write', s.school_id))
    )
  )
  with check (true);

create policy student_guardians_read on public.student_guardians
  for select to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_guardians.student_id
        and (select private.has_permission('people.read', s.school_id))
    )
  );

create policy student_guardians_manage on public.student_guardians
  for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_guardians.student_id
        and (select private.has_permission('people.write', s.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_guardians.student_id
        and (select private.has_permission('people.write', s.school_id))
    )
  );

create policy teachers_read on public.teachers
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy teachers_manage on public.teachers
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy staff_read on public.staff_members
  for select to authenticated
  using ((select private.has_permission('people.read', school_id)));

create policy staff_manage on public.staff_members
  for all to authenticated
  using ((select private.has_permission('people.write', school_id)))
  with check ((select private.has_permission('people.write', school_id)));

create policy employments_read on public.employments
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy employments_manage on public.employments
  for all to authenticated
  using ((select private.has_permission('administration.manage', school_id)))
  with check ((select private.has_permission('administration.manage', school_id)));

create policy app_accounts_self_or_admin_read on public.app_accounts
  for select to authenticated
  using (
    auth_user_id = (select auth.uid())
    or (select private.has_permission('administration.manage', school_id))
  );

create policy app_accounts_admin_manage on public.app_accounts
  for all to authenticated
  using ((select private.has_permission('administration.manage', school_id)))
  with check ((select private.has_permission('administration.manage', school_id)));

create policy account_roles_admin_all on public.account_roles
  for all to authenticated
  using (
    exists (
      select 1 from public.app_accounts aa
      where aa.id = account_roles.account_id
        and (select private.has_permission('administration.manage', aa.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.app_accounts aa
      where aa.id = account_roles.account_id
        and (select private.has_permission('administration.manage', aa.school_id))
    )
  );

create policy grade_levels_read on public.grade_levels
  for select to authenticated
  using ((select private.has_permission('academic.read')));

create policy grade_levels_manage on public.grade_levels
  for all to authenticated
  using ((select private.has_permission('academic.manage')))
  with check ((select private.has_permission('academic.manage')));

create policy subjects_read on public.subjects
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy subjects_manage on public.subjects
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy curriculum_read on public.curriculum_subjects
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy curriculum_manage on public.curriculum_subjects
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy class_groups_read on public.class_groups
  for select to authenticated
  using ((select private.has_permission('academic.read', school_id)));

create policy class_groups_manage on public.class_groups
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy enrollments_read on public.student_enrollments
  for select to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_enrollments.student_id
        and (select private.has_permission('enrollment.read', s.school_id))
    )
  );

create policy enrollments_manage on public.student_enrollments
  for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_enrollments.student_id
        and (select private.has_permission('enrollment.manage', s.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_enrollments.student_id
        and (select private.has_permission('enrollment.manage', s.school_id))
    )
  );

create policy placements_read on public.class_placements
  for select to authenticated
  using (
    exists (
      select 1
      from public.student_enrollments e
      join public.students s on s.id = e.student_id
      where e.id = class_placements.enrollment_id
        and (select private.has_permission('enrollment.read', s.school_id))
    )
  );

create policy placements_manage on public.class_placements
  for all to authenticated
  using (
    exists (
      select 1
      from public.student_enrollments e
      join public.students s on s.id = e.student_id
      where e.id = class_placements.enrollment_id
        and (select private.has_permission('enrollment.manage', s.school_id))
    )
  )
  with check (
    exists (
      select 1
      from public.student_enrollments e
      join public.students s on s.id = e.student_id
      where e.id = class_placements.enrollment_id
        and (select private.has_permission('enrollment.manage', s.school_id))
    )
  );

create policy offerings_read on public.course_offerings
  for select to authenticated
  using (
    (select private.has_permission('academic.read', school_id))
    or exists (
      select 1
      from public.teacher_assignments ta
      where ta.course_offering_id = course_offerings.id
        and exists (
          select 1 from public.teachers t
          where t.id = ta.teacher_id
            and t.person_id = (
              select aa.id from public.app_accounts aa
              where aa.auth_user_id = (select auth.uid())
              limit 1
            )
        )
    )
  );

create policy offerings_manage on public.course_offerings
  for all to authenticated
  using ((select private.has_permission('academic.manage', school_id)))
  with check ((select private.has_permission('academic.manage', school_id)));

create policy assignments_read on public.teacher_assignments
  for select to authenticated
  using (
    (select private.has_permission('academic.read'))
    or exists (
      select 1
      from public.teachers t
      join public.app_accounts aa on aa.auth_user_id = (select auth.uid())
      where t.id = teacher_assignments.teacher_id
        and aa.status = 'ACTIVE'
        and t.person_id = aa.id
    )
  );

create policy assignments_manage on public.teacher_assignments
  for all to authenticated
  using (
    exists (
      select 1
      from public.course_offerings co
      where co.id = teacher_assignments.course_offering_id
        and (select private.has_permission('academic.manage', co.school_id))
    )
  )
  with check (
    exists (
      select 1
      from public.course_offerings co
      where co.id = teacher_assignments.course_offering_id
        and (select private.has_permission('academic.manage', co.school_id))
    )
  );

create policy participations_read on public.student_course_participations
  for select to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = student_course_participations.course_offering_id
        and (select private.has_permission('academic.read', co.school_id))
    )
  );

create policy participations_manage on public.student_course_participations
  for all to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = student_course_participations.course_offering_id
        and (select private.has_permission('academic.manage', co.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.course_offerings co
      where co.id = student_course_participations.course_offering_id
        and (select private.has_permission('academic.manage', co.school_id))
    )
  );

create policy assessment_periods_read on public.assessment_periods
  for select to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = assessment_periods.academic_year_id
        and (select private.has_permission('assessment.read', ay.school_id))
    )
  );

create policy assessment_periods_manage on public.assessment_periods
  for all to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = assessment_periods.academic_year_id
        and (select private.has_permission('assessment.manage', ay.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.academic_years ay
      where ay.id = assessment_periods.academic_year_id
        and (select private.has_permission('assessment.manage', ay.school_id))
    )
  );

create policy assessments_read on public.assessments
  for select to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = assessments.course_offering_id
        and (
          (select private.has_permission('assessment.read', co.school_id))
          or (
            (select private.has_permission('assessment.own.read', co.school_id))
            and exists (
              select 1 from public.teacher_assignments ta
              join public.teachers t on t.id = ta.teacher_id
              where ta.course_offering_id = co.id
                and t.person_id = (select aa.id from public.app_accounts aa where aa.auth_user_id = (select auth.uid()) limit 1)
                and ta.active
            )
          )
        )
    )
  );

create policy assessments_manage on public.assessments
  for all to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = assessments.course_offering_id
        and (select private.has_permission('assessment.manage', co.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.course_offerings co
      where co.id = assessments.course_offering_id
        and (select private.has_permission('assessment.manage', co.school_id))
    )
  );

create policy assessment_results_read on public.assessment_results
  for select to authenticated
  using (
    exists (
      select 1
      from public.assessments a
      join public.course_offerings co on co.id = a.course_offering_id
      where a.id = assessment_results.assessment_id
        and (
          (select private.has_permission('assessment.read', co.school_id))
          or (
            (select private.has_permission('assessment.own.read', co.school_id))
            and exists (
              select 1 from public.teacher_assignments ta
              join public.teachers t on t.id = ta.teacher_id
              where ta.course_offering_id = co.id
                and t.person_id = (select aa.id from public.app_accounts aa where aa.auth_user_id = (select auth.uid()) limit 1)
                and ta.active
            )
          )
        )
    )
  );

create policy assessment_results_manage on public.assessment_results
  for all to authenticated
  using (
    exists (
      select 1
      from public.assessments a
      join public.course_offerings co on co.id = a.course_offering_id
      where a.id = assessment_results.assessment_id
        and (
          (select private.has_permission('assessment.manage', co.school_id))
          or (
            (select private.has_permission('assessment.own.enter', co.school_id))
            and exists (
              select 1 from public.teacher_assignments ta
              join public.teachers t on t.id = ta.teacher_id
              where ta.course_offering_id = co.id
                and t.person_id = (select aa.id from public.app_accounts aa where aa.auth_user_id = (select auth.uid()) limit 1)
                and ta.active
            )
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from public.assessments a
      join public.course_offerings co on co.id = a.course_offering_id
      where a.id = assessment_results.assessment_id
        and (
          (select private.has_permission('assessment.manage', co.school_id))
          or (
            (select private.has_permission('assessment.own.enter', co.school_id))
            and exists (
              select 1 from public.teacher_assignments ta
              join public.teachers t on t.id = ta.teacher_id
              where ta.course_offering_id = co.id
                and t.person_id = (select aa.id from public.app_accounts aa where aa.auth_user_id = (select auth.uid()) limit 1)
                and ta.active
            )
          )
        )
    )
  );

create policy grade_rules_read on public.grade_rule_versions
  for select to authenticated
  using ((select private.has_permission('assessment.read', school_id)));

create policy grade_rules_manage on public.grade_rule_versions
  for all to authenticated
  using ((select private.has_permission('assessment.manage', school_id)))
  with check ((select private.has_permission('assessment.manage', school_id)));

create policy academic_results_read on public.academic_results
  for select to authenticated
  using (
    exists (
      select 1
      from public.course_offerings co
      where co.id = academic_results.course_offering_id
        and (select private.has_permission('assessment.read', co.school_id))
    )
  );

create policy academic_results_manage on public.academic_results
  for all to authenticated
  using (
    exists (
      select 1
      from public.course_offerings co
      where co.id = academic_results.course_offering_id
        and (select private.has_permission('assessment.manage', co.school_id))
    )
  )
  with check (
    exists (
      select 1
      from public.course_offerings co
      where co.id = academic_results.course_offering_id
        and (select private.has_permission('assessment.manage', co.school_id))
    )
  );
