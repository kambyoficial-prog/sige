import Link from "next/link";
import type { ColumnDef } from "@tanstack/react-table";
import type { EnrollmentDirectory } from "@sige/contracts";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { searchEnrollmentDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { cn } from "@/lib/utils";

export default async function EnrollmentsPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams; const access=await getCurrentAccessContext(); const canManage=access.memberships.some((m)=>m.permissions.includes("enrollment.manage")); const search=params.q?.trim()??""; const rows=await searchEnrollmentDirectory(search);
  const columns:ColumnDef<DataTableFeatures,EnrollmentDirectory,unknown>[]=[
    {accessorKey:"school_number",header:"N.º"},
    {accessorKey:"student_name",header:"Aluno",cell:({row})=><Link className="font-medium hover:underline" href={`/matriculas/${row.original.id}`}>{row.original.student_name}</Link>},
    {accessorKey:"academic_year_label",header:"Ano letivo"},
    {accessorKey:"grade_level_name",header:"Classe"},
    {accessorKey:"class_name",header:"Turma",cell:({getValue})=>getValue<string>()||"Sem turma"},
    {accessorKey:"status",header:"Estado",cell:({getValue})=><Badge variant="secondary">{getValue<string>()}</Badge>},
  ];
  return <div className="space-y-6"><PageHeader title="Matrículas" description="Matrículas anuais e respetivos episódios de permanência." actions={canManage?<Link href="/matriculas/nova" className={buttonVariants()}>Nova matrícula</Link>:null}/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar aluno, número ou turma…" className="h-10 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button>{search?<Link href="/matriculas" className={cn(buttonVariants({variant:"ghost"}))}>Limpar</Link>:null}</form><DataTable columns={columns} data={rows} emptyTitle="Sem matrículas" emptyDescription={search?"A pesquisa não encontrou correspondências.":"Ainda não existem matrículas registadas."}/></div>;
}
