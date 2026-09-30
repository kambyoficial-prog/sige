import Link from "next/link";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { searchStudentDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { cn } from "@/lib/utils";

type StudentFilter = "todos" | "pendentes" | "sem-turma" | "matriculados";

export default async function StudentsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; estado?: StudentFilter }>;
}) {
  const params = await searchParams;
  const access = await getCurrentAccessContext();
  const canManage = access.memberships.some((m) => m.permissions.includes("enrollment.manage"));
  const search = params.q?.trim() ?? "";
  const filter: StudentFilter = ["todos", "pendentes", "sem-turma", "matriculados"].includes(params.estado ?? "")
    ? (params.estado as StudentFilter)
    : "todos";

  const allRows = await searchStudentDirectory(search);
  const pendingCount = allRows.filter((row) => !row.enrollment_status).length;
  const noClassCount = allRows.filter((row) => row.enrollment_status && !row.class_name).length;
  const enrolledCount = allRows.filter((row) => Boolean(row.enrollment_status)).length;

  const rows = allRows.filter((row) => {
    if (filter === "pendentes") return !row.enrollment_status;
    if (filter === "sem-turma") return Boolean(row.enrollment_status) && !row.class_name;
    if (filter === "matriculados") return Boolean(row.enrollment_status);
    return true;
  });

  const filterHref = (value: StudentFilter) => {
    const params = new URLSearchParams();
    if (search) params.set("q", search);
    if (value !== "todos") params.set("estado", value);
    const query = params.toString();
    return query ? `/alunos?${query}` : "/alunos";
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Alunos"
        description="O ponto de trabalho da Secretaria para localizar, registar e acompanhar cada aluno."
        actions={canManage ? <Link href="/alunos/novo" className={buttonVariants()}>Novo aluno</Link> : null}
      />

      <form method="get" className="flex flex-col gap-2 sm:flex-row">
        {filter !== "todos" ? <input type="hidden" name="estado" value={filter} /> : null}
        <input
          name="q"
          defaultValue={search}
          placeholder="Nome, número do aluno ou outro dado conhecido…"
          className="h-10 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm"
          autoComplete="off"
        />
        <Button type="submit" variant="outline">Pesquisar</Button>
        {search || filter !== "todos" ? (
          <Link href="/alunos" className={cn(buttonVariants({ variant: "ghost" }))}>Limpar</Link>
        ) : null}
      </form>

      <nav aria-label="Estado dos alunos" className="flex flex-wrap items-center gap-1 border-b border-border pb-3">
        {[
          ["todos", `Todos · ${allRows.length}`],
          ["pendentes", `Sem matrícula · ${pendingCount}`],
          ["sem-turma", `Sem turma · ${noClassCount}`],
          ["matriculados", `Matriculados · ${enrolledCount}`],
        ].map(([value, label]) => (
          <Link
            key={value}
            href={filterHref(value as StudentFilter)}
            className={cn(
              buttonVariants({ variant: filter === value ? "secondary" : "ghost", size: "sm" }),
              "rounded-full"
            )}
          >
            {label}
          </Link>
        ))}
      </nav>

      <div className="flex items-center justify-between gap-4 text-sm text-muted-foreground">
        <p>
          {search ? `${allRows.length} resultado(s) para “${search}”.` : `${allRows.length} aluno(s) no diretório.`}
          {filter === "pendentes" ? " A matrícula ainda não foi iniciada." : null}
          {filter === "sem-turma" ? " A matrícula existe, mas a turma ainda não foi atribuída." : null}
        </p>
        {filter !== "todos" ? <Link href="/alunos" className="font-medium text-foreground hover:underline">Ver todos</Link> : null}
      </div>

      <DirectoryTable
        kind="students"
        data={rows}
        emptyTitle={search ? "Nenhum aluno encontrado" : "Sem alunos"}
        emptyDescription={
          filter === "pendentes"
            ? "Não há alunos pendentes de matrícula neste resultado."
            : filter === "sem-turma"
              ? "Não há matrículas sem turma neste resultado."
              : search
                ? "A pesquisa não encontrou correspondências."
                : "Ainda não existem alunos registados nesta escola."
        }
      />
    </div>
  );
}
