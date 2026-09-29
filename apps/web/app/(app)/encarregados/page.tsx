import type { ColumnDef } from "@tanstack/react-table";
import type { GuardianDirectory } from "@sige/contracts";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { searchGuardianDirectory } from "@/lib/sige/queries";

export default async function GuardiansPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams; const search=params.q?.trim()??""; const rows=await searchGuardianDirectory(search);
  const columns:ColumnDef<DataTableFeatures,GuardianDirectory,unknown>[]=[
    {accessorKey:"full_name",header:"Encarregado"},
    {accessorKey:"relationship",header:"Relação",cell:({getValue})=>getValue<string>()||"—"},
    {accessorKey:"phone",header:"Telefone",cell:({getValue})=>getValue<string>()||"—"},
    {accessorKey:"student_count",header:"Alunos"},
  ];
  return <div className="space-y-6"><PageHeader title="Encarregados" description="Relações familiares e responsáveis associados aos alunos."/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar por nome ou documento…" className="h-10 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button></form><DataTable columns={columns} data={rows}/></div>;
}
