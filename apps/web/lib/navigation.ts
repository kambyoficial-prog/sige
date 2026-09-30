export type NavigationSection = { label: string; items: NavigationItem[] };
export type NavigationItem = { label: string; href: string; permission?: string };
export const navigationSections: NavigationSection[] = [
  { label: "Conta", items: [{ label: "Perfil", href: "/perfil" }] },
  { label: "Visão geral", items: [{ label: "Visão geral", href: "/" }] },
  { label: "Pessoas", items: [
    { label: "Alunos", href: "/alunos", permission: "enrollment.read" },
    { label: "Professores", href: "/professores", permission: "operations.read" },
    { label: "Funcionários", href: "/funcionarios", permission: "user.read" },
    { label: "Encarregados", href: "/encarregados", permission: "enrollment.read" },
  ] },
  { label: "Matrícula e inscrição", items: [
    { label: "Matrículas", href: "/matriculas", permission: "enrollment.read" },
    { label: "Inscrições", href: "/inscricoes", permission: "enrollment.read" },
  ] },
  { label: "Pedagógico", items: [
    { label: "Turmas", href: "/turmas", permission: "operations.read" }, { label: "Notas", href: "/notas", permission: "assessment.read" },
    { label: "Pautas", href: "/pautas", permission: "assessment.read" }, { label: "Exames", href: "/exames", permission: "assessment.manage" },
  ] },
  { label: "Operações", items: [{ label: "Horários", href: "/horarios", permission: "operations.read" }, { label: "Livro de ponto", href: "/livro-de-ponto", permission: "operations.read" }] },
  { label: "Financeiro", items: [{ label: "Propinas", href: "/financeiro/propinas", permission: "finance.read" }, { label: "Pagamentos", href: "/financeiro/pagamentos", permission: "finance.read" }, { label: "Saldos", href: "/financeiro/saldos", permission: "finance.read" }, { label: "Configuração", href: "/financeiro/configuracao", permission: "finance.manage" }] },
  { label: "Relatórios", items: [{ label: "Relatórios", href: "/relatorios" }] },
];