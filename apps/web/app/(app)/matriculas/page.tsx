import Link from "next/link";
import type { EnrollmentDirectory } from "@sige/contracts";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { searchEnrollmentDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { cn } from "@/lib/utils";

export default async function EnrollmentsPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams;
  const access=await getCurrentAccessContext();
  const canManage=access.memberships.some((m)=>m.permissions.includes("enrollment.manage"));
  const search=params.q?.trim()??"";
  const rows: EnrollmentDirectory[] = await searchEnrollmentDirectory(search);
  return <div className="space-y-6"><PageHeader title="Matrículas" description="Matrículas anuais e respetivos episódios de permanência." actions={canManage?<Link href="/matriculas/nova" className={buttonVariants()}>Nova matrícula</Link>:null}/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar aluno, número ou turma…" className="h-10 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button>{search?<Link href="/matriculas" className={cn(buttonVariants({variant:"ghost"}))}>Limpar</Link>:null}</form><DirectoryTable kind="enrollments" data={rows} emptyTitle="Sem matrículas" emptyDescription={search?"A pesquisa não encontrou correspondências.":"Ainda não existem matrículas registadas."}/></div>;
}
