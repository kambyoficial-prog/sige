export type NavigationSection = {
  label: string;
  items: NavigationItem[];
};

export type NavigationItem = {
  label: string;
  href: string;
  permission?: string;
};

export const navigationSections: NavigationSection[] = [
  {
    label: "Visão geral",
    items: [{ label: "Visão geral", href: "/" }],
  },
  {
    label: "Pessoas",
    items: [
      { label: "Alunos", href: "/alunos", permission: "enrollment.read" },
      { label: "Professores", href: "/professores", permission: "operations.read" },
      { label: "Encarregados", href: "/encarregados", permission: "enrollment.read" },
    ],
  },
  {
    label: "Matrículas",
    items: [{ label: "Matrículas", href: "/matriculas", permission: "enrollment.read" }],
  },
  {
    label: "Pedagógico",
    items: [
      { label: "Turmas", href: "/turmas", permission: "operations.read" },
      { label: "Notas", href: "/notas", permission: "assessment.read" },
      { label: "Pautas", href: "/pautas", permission: "assessment.read" },
    ],
  },
  {
    label: "Operações",
    items: [
      { label: "Horários", href: "/horarios", permission: "operations.read" },
      { label: "Livro de ponto", href: "/livro-de-ponto", permission: "attendance.own.manage" },
    ],
  },
  {
    label: "Financeiro",
    items: [
      { label: "Propinas", href: "/financeiro/propinas", permission: "finance.read" },
      { label: "Pagamentos", href: "/financeiro/pagamentos", permission: "finance.read" },
      { label: "Saldos", href: "/financeiro/saldos", permission: "finance.read" },
    ],
  },
  {
    label: "Relatórios",
    items: [{ label: "Relatórios", href: "/relatorios", permission: "reports.read" }],
  },
];
