import { redirect } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { StudentForm } from "@/components/people/student-form";
import { getCurrentAccessContext } from "@/lib/sige/access";

export default async function NewStudentPage() {
  const access = await getCurrentAccessContext();
  if (!access.memberships.some((m) => m.permissions.includes("enrollment.manage"))) redirect("/acesso-negado");
  const schools = access.memberships.map((m) => ({ id: m.school_id, name: m.school_name, code: m.school_code }));
  if (!schools.length) redirect("/acesso-negado");
  return <div className="space-y-6"><PageHeader title="Novo aluno" description="Admissão guiada. Depois da identidade, o SIGE conduz a secretaria pela matrícula e restantes etapas." /><div className="rounded-xl border border-border bg-card p-5 sm:p-7"><StudentForm schools={schools} /></div></div>;
}
