import { notFound, redirect } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { GuardianForm } from "@/components/people/guardian-form";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { getStudentProfile } from "@/lib/sige/queries";

export default async function NewGuardianPage({params}:{params:Promise<{id:string}>}){
 const {id}=await params;const access=await getCurrentAccessContext();if(!access.memberships.some((m)=>m.permissions.includes("enrollment.manage")))redirect("/acesso-negado");
 const profile=(await getStudentProfile(id))[0];if(!profile)notFound();
 const school=access.memberships.find((m)=>m.school_id===profile.school_id);if(!school)redirect("/acesso-negado");
 return <div className="space-y-6"><PageHeader title="Novo encarregado" description={`Associar um responsável ao aluno ${profile.full_name}.`}/><div className="rounded-xl border border-border bg-card p-6 sm:p-8"><GuardianForm schoolId={school.school_id} studentId={profile.id}/></div></div>;
}
