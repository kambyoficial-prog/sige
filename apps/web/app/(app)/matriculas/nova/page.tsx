import { redirect } from "next/navigation";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { PageHeader } from "@/components/ui/page-header";
import { EnrollmentForm } from "@/components/enrollment/enrollment-form";
import { getAcademicPathwayOptions, getAcademicYearOptions, getGradeLevelOptions, searchStudentDirectory } from "@/lib/sige/queries";

export default async function NewEnrollmentPage({searchParams}:{searchParams:Promise<{studentId?:string}>}) {
  const params=await searchParams;
  const access = await getCurrentAccessContext();
  if (!access.memberships.some((m) => m.permissions.includes("enrollment.manage"))) redirect("/acesso-negado");
  const [students,years,grades]=await Promise.all([searchStudentDirectory(),getAcademicYearOptions(),getGradeLevelOptions()]);
  const secondCycleId = grades.find((g) => ["11","12"].includes(g.code))?.academic_cycle_id;
  const pathways = await getAcademicPathwayOptions(secondCycleId);
  return <div className="space-y-6"><PageHeader title="Nova matrícula" description="A matrícula anual é separada do registo de identidade e da colocação numa turma."/><div className="rounded-xl border border-border bg-card p-6 sm:p-8"><EnrollmentForm students={students.map(s=>({id:s.id,full_name:s.full_name,school_number:s.school_number}))} years={years} grades={grades} pathways={pathways} initialStudentId={params.studentId}/></div></div>;
}
