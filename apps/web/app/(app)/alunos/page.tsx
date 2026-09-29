import Link from "next/link";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { searchStudentDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { cn } from "@/lib/utils";

export default async function StudentsPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const params = await searchParams;
  const access = await getCurrentAccessContext();
  const canManage = access.memberships.some((m) => m.permissions.includes("enrollment.manage"));
  const search = params.q?.trim() ?? "";
  const rows = await searchStudentDirectory(search);

  return (
    <div className="space-y-6">
      <PageHeader title="Alunos" description="Diretório institucional dos alunos, com o contexto académico atual." actions={canManage ? <Link href="/alunos/novo" className={buttonVariants()}>Novo aluno</Link> : null} />
      <form method="get" className="flex gap-2">
        <input name="q" defaultValue={search} placeholder="Pesquisar por nome ou número…" className="h-10 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md" />
        <Button type="submit" variant="outline">Pesquisar</Button>
        {search ? <Link href="/alunos" className={cn(buttonVariants({ variant: "ghost" }))}>Limpar</Link> : null}
      </form>
      <DirectoryTable kind="students" data={rows} emptyTitle={search ? "Nenhum aluno encontrado" : "Sem alunos"} emptyDescription={search ? "A pesquisa não encontrou correspondências." : "Ainda não existem alunos registados nesta escola."} />
    </div>
  );
}
