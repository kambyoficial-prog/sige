import Link from "next/link";
import type { ClassGroupDirectory } from "@sige/contracts";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getClassGroupDirectory } from "@/lib/sige/queries";
import { getCurrentAccessContext } from "@/lib/sige/access";

export default async function ClassesPage(){
 const access=await getCurrentAccessContext();
 const canManage=access.memberships.some((m)=>m.permissions.includes("operations.manage"));
 const rows: ClassGroupDirectory[] = await getClassGroupDirectory();
 return <div className="space-y-6"><PageHeader title="Turmas" description="Estrutura operacional das turmas por ano, classe e secção." actions={canManage?<Link href="/turmas/nova" className={buttonVariants()}>Nova turma</Link>:null}/><DirectoryTable kind="classes" data={rows} emptyTitle="Sem turmas" emptyDescription="Ainda não existem turmas configuradas."/></div>
}
