import { redirect } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { AdmissionWorkflow } from "@/components/people/admission-workflow";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { getAcademicPathwayOptions, getAcademicYearOptions, getClassGroupDirectory, getGradeLevelOptions } from "@/lib/sige/queries";

export default async function NewStudentPage() {
  const access = await getCurrentAccessContext();
  if (!access.memberships.some((m) => m.permissions.includes("enrollment.manage"))) redirect("/acesso-negado");

  const school = access.memberships.find((m) => m.permissions.includes("enrollment.manage"));
  if (!school) redirect("/acesso-negado");

  const [years, grades, pathways, classes] = await Promise.all([
    getAcademicYearOptions(),
    getGradeLevelOptions(),
    getAcademicPathwayOptions(),
    getClassGroupDirectory(),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader title="Novo aluno" description="Um único processo para registar o aluno e deixá-lo pronto para frequentar a escola." />
      <AdmissionWorkflow
        school={{ id: school.school_id, name: school.school_name, code: school.school_code }}
        years={years}
        grades={grades}
        pathways={pathways}
        classes={classes}
      />
    </div>
  );
}
