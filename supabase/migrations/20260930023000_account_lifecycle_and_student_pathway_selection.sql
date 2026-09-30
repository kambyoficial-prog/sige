-- SIGE — account lifecycle + student pathway selection
-- Closes the documented first-access state and preserves pathway choices
-- as historical domain data. Pathway definitions remain school-configurable.

alter table public.app_accounts
  add column if not exists first_access_required boolean not null default false,
  add column if not exists credential_issued_at timestamptz,
  add column if not exists activated_at timestamptz,
  add column if not exists suspended_at timestamptz;

create table if not exists public.student_pathway_selections (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  source_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  target_cycle_id uuid not null references public.academic_cycles(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  pathway_id uuid not null references public.academic_pathways(id) on delete restrict,
  status text not null default 'SELECTED',
  selected_at timestamptz not null default now(),
  selected_by uuid references auth.users(id) on delete set null,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  constraint student_pathway_selection_status_ck
    check (status in ('SELECTED','CONFIRMED','CANCELLED')),
  unique (student_id, academic_year_id, target_cycle_id)
);

create index if not exists student_pathway_selections_student_idx
  on public.student_pathway_selections(student_id, academic_year_id);

alter table public.student_pathway_selections enable row level security;

drop policy if exists student_pathway_selections_read on public.student_pathway_selections;
create policy student_pathway_selections_read
on public.student_pathway_selections
for select to authenticated
using (
  private.has_permission('enrollment.read', (select s.school_id from public.students s where s.id = student_id))
  or private.has_permission('enrollment.manage', (select s.school_id from public.students s where s.id = student_id))
);

insert into public.permissions (code,name,description) values
  ('user.read','Consultar utilizadores','Consultar contas institucionais e respetivo estado.'),
  ('user.create','Criar utilizadores','Criar e ativar contas institucionais.'),
  ('user.update','Gerir utilizadores','Alterar dados operacionais da conta.'),
  ('user.suspend','Suspender utilizadores','Suspender ou reativar contas institucionais.'),
  ('teacher.manage','Gerir professores','Criar, editar, atribuir e desativar professores.'),
  ('staff.manage','Gerir funcionários','Criar, editar e desativar funcionários institucionais.'),
  ('guardian.manage','Gerir encarregados','Criar e gerir responsáveis e vínculos aos alunos.'),
  ('academic.pathway.select','Registar escolha de percurso','Registar e confirmar o percurso académico do aluno.')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on (
  (r.code='DIRECTION' and p.code in ('user.read','user.create','user.update','user.suspend','teacher.manage','staff.manage','guardian.manage','academic.pathway.select'))
  or
  (r.code='SECRETARIAT' and p.code in ('user.read','user.create','user.update','user.suspend','teacher.manage','staff.manage','guardian.manage','academic.pathway.select'))
  or
  (r.code='PEDAGOGICAL_DIRECTION' and p.code in ('teacher.manage','academic.pathway.select'))
)
on conflict do nothing;

insert into public.roles (code,name,description)
values ('FINANCE','Financeiro','Gestão financeira institucional.')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('finance.read','finance.manage')
where r.code='FINANCE'
on conflict do nothing;
