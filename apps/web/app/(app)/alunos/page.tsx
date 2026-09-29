import Link from "next/link";
import type { ColumnDef } from "@tanstack/react-table";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { searchStudentDirectory } from "@/lib/sige/queries";
import type { StudentDirectory } from "@sige/contracts";
import { cn } from "@/lib/utils";

export default async function StudentsPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const params = await searchParams;
  const search = params.q?.trim() ?? "";
  const rows = await searchStudentDirectory(search);
  const columns: ColumnDef<DataTableFeatures, StudentDirectory, unknown>[] = [
    { accessorKey: "school_number", header: "N.º" },
    { accessorKey: "full_name", header: "Aluno", cell: ({ row }) => <Link className="font-medium hover:underline" href={`/alunos/${row.original.id}`}>{row.original.full_name}</Link> },
    { accessorKey: "gender", header: "Sexo", cell: ({ getValue }) => getValue<string>() || "—" },
    { accessorKey: "class_name", header: "Turma", cell: ({ getValue }) => getValue<string>() || "Sem turma" },
    { accessorKey: "enrollment_status", header: "Matrícula", cell: ({ getValue }) => <Badge variant="secondary">{getValue<string>() || "Sem matrícula"}</Badge> },
  ];

  return (
    <div className="space-y-6">
      <PageHeader title="Alunos" description="Diretório institucional dos alunos, com o contexto académico atual." actions={<Link href="/alunos/novo" className={buttonVariants()}>Novo aluno</Link>} />
      <form method="get" className="flex gap-2">
        <input name="q" defaultValue={search} placeholder="Pesquisar por nome ou número…" className="h-10 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md" />
        <Button type="submit" variant="outline">Pesquisar</Button>
        {search ? <Link href="/alunos" className={cn(buttonVariants({ variant: "ghost" }))}>Limpar</Link> : null}
      </form>
      <DataTable columns={columns} data={rows} emptyTitle={search ? "Nenhum aluno encontrado" : "Sem alunos"} emptyDescription={search ? "A pesquisa não encontrou correspondências." : "Ainda não existem alunos registados nesta escola."} />
    </div>
  );
}
