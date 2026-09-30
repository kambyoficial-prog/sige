export type NavigationSection = { label: string; items: NavigationItem[] };
export type NavigationItem = {
  label: string;
  href: string;
  permission?: string;
  roles?: string[];
};

export const navigationSections: NavigationSection[] = [
  { label: "Conta", items: [{ label: "Perfil", href: "/perfil" }] },
  { label: "Visão geral", items: [{ label: "Visão geral", href: "/" }] },
  {
    label: "Pessoas",
    items: [
      { label: "Alunos", href: "/alunos", permission: "enrollment.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT"] },
      { label: "Professores", href: "/professores", permission: "operations.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT"] },
      { label: "Funcionários", href: "/funcionarios", permission: "user.read", roles: ["DIRECTION", "SECRETARIAT"] },
      { label: "Encarregados", href: "/encarregados", permission: "enrollment.read", roles: ["DIRECTION", "SECRETARIAT"] },
    ],
  },
  {
    label: "Matrícula e inscrição",
    items: [
      { label: "Matrículas", href: "/matriculas", permission: "enrollment.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT"] },
      { label: "Inscrições", href: "/inscricoes", permission: "enrollment.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT"] },
    ],
  },
  {
    label: "Pedagógico",
    items: [
      { label: "Turmas", href: "/turmas", permission: "operations.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT", "TEACHER", "STUDENT"] },
      { label: "Notas", href: "/notas", permission: "assessment.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT", "TEACHER", "STUDENT"] },
      { label: "Pautas", href: "/pautas", permission: "assessment.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT", "TEACHER"] },
      { label: "Exames", href: "/exames", permission: "assessment.manage", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION"] },
    ],
  },
  {
    label: "Operações",
    items: [
      { label: "Horários", href: "/horarios", permission: "operations.read", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT", "TEACHER", "STUDENT"] },
      { label: "Livro de ponto", href: "/livro-de-ponto", permission: "operations.read", roles: ["DIRECTION", "SECRETARIAT", "TEACHER"] },
    ],
  },
  {
    label: "Financeiro",
    items: [
      { label: "Propinas", href: "/financeiro/propinas", permission: "finance.read", roles: ["DIRECTION", "FINANCE"] },
      { label: "Pagamentos", href: "/financeiro/pagamentos", permission: "finance.read", roles: ["DIRECTION", "FINANCE"] },
      { label: "Saldos", href: "/financeiro/saldos", permission: "finance.read", roles: ["DIRECTION", "FINANCE"] },
      { label: "Configuração", href: "/financeiro/configuracao", permission: "finance.manage", roles: ["DIRECTION", "FINANCE"] },
    ],
  },
  { label: "Relatórios", items: [{ label: "Relatórios", href: "/relatorios", roles: ["DIRECTION", "PEDAGOGICAL_DIRECTION", "SECRETARIAT"] }] },
];