import Link from "next/link";
import Link from "next/link";
import type { ColumnDef } from "@tanstack/react-table";
import type { TeacherDirectory } from "@sige/contracts";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { searchTeacherDirectory } from "@/lib/sige/queries";

export default async function TeachersPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams; const search=params.q?.trim()??""; const rows=await searchTeacherDirectory(search);
  const columns:ColumnDef<DataTableFeatures,TeacherDirectory,unknown>[]=[
    {accessorKey:"employee_code",header:"Código"},
    {accessorKey:"full_name",header:"Professor",cell:({row})=><Link className="font-medium hover:underline" href={`/professores/${row.original.id}`}>{row.original.full_name}</Link>},
    {accessorKey:"phone",header:"Telefone",cell:({getValue})=>getValue<string>()||"—"},
    {accessorKey:"email",header:"Email",cell:({getValue})=>getValue<string>()||"—"},
    {accessorKey:"status",header:"Estado"},
  ];
  return <div className="space-y-6"><PageHeader title="Professores" description="Diretório institucional dos docentes."/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar por nome ou código…" className="h-10 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button></form><DataTable columns={columns} data={rows}/></div>;
}
