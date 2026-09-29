import Link from "next/link";
import type { ColumnDef } from "@tanstack/react-table";
import type { ClassGroupDirectory } from "@sige/contracts";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { getClassGroupDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";

export default async function ClassesPage(){
 const access=await getCurrentAccessContext(); const canManage=access.memberships.some((m)=>m.permissions.includes("operations.manage"));
 const rows=await getClassGroupDirectory();
 const columns:ColumnDef<DataTableFeatures,ClassGroupDirectory,unknown>[]=[
  {accessorKey:"academic_year_label",header:"Ano letivo"},
  {accessorKey:"grade_level_name",header:"Classe"},
  {accessorKey:"name",header:"Turma",cell:({row})=><Link href={`/turmas/${row.original.id}`} className="font-medium hover:underline">{row.original.name||row.original.section_code}</Link>},
  {accessorKey:"shift",header:"Turno",cell:({getValue})=><span>{getValue<string>()||"—"}</span>},
  {accessorKey:"student_count",header:"Alunos"},
  {accessorKey:"director_teacher_name",header:"Diretor de turma",cell:({getValue})=><span>{getValue<string>()||"—"}</span>},
  {accessorKey:"status",header:"Estado",cell:({getValue})=><Badge variant="secondary">{getValue<string>()}</Badge>},
 ];
 return <div className="space-y-6"><PageHeader title="Turmas" description="Estrutura operacional das turmas por ano, classe e secção." actions={canManage?<Link href="/turmas/nova" className={buttonVariants()}>Nova turma</Link>:null}/><DataTable columns={columns} data={rows} emptyTitle="Sem turmas" emptyDescription="Ainda não existem turmas configuradas."/></div>
}
