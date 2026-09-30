import {redirect} from "next/navigation";
import {PageHeader} from "@/components/ui/page-header";
import {buttonVariants} from "@/components/ui/button";
import {getCurrentAccessContext} from "@/lib/sige/access";
import {TeacherForm} from "@/components/teachers/teacher-form";
import Link from "next/link";
export default async function NewTeacherPage(){const access=await getCurrentAccessContext();const school=access.memberships.find(m=>m.permissions.includes("teacher.manage"));if(!school)redirect("/acesso-negado");return <div className="space-y-6"><PageHeader title="Novo professor" description="Registar um docente. O e-mail institucional não é obrigatório."/><div className="rounded-xl border border-border bg-card p-6 sm:p-8"><TeacherForm schoolId={school.school_id}/></div><Link href="/professores" className={buttonVariants({variant:"outline"})}>Cancelar</Link></div>}