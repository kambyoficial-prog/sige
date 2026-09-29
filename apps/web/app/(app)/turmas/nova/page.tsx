import { redirect } from "next/navigation";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { PageHeader } from "@/components/ui/page-header";
import { ClassForm } from "@/components/classes/class-form";
import { getAcademicYearOptions, getGradeLevelOptions } from "@/lib/sige/queries";
export default async function NewClassPage(){
 const access=await getCurrentAccessContext(); if(!access.memberships.some((m)=>m.permissions.includes("operations.manage"))) redirect("/acesso-negado");const[years,grades]=await Promise.all([getAcademicYearOptions(),getGradeLevelOptions()]);return <div className="space-y-6"><PageHeader title="Nova turma" description="Criação de uma turma anual. Disciplinas e docentes são operações posteriores e dependem do currículo."/><div className="rounded-xl border border-border bg-card p-6 sm:p-8"><ClassForm years={years} grades={grades}/></div></div>}
