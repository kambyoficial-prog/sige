import Link from "next/link";
import { redirect } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import {
  getAcademicResultPauta,
  getAcademicYearOptions,
  getAssessmentGradebook,
  getClassGroupDirectory,
  getClassGroupStudents,
  getCourseOfferings,
  getStudentDirectory,
} from "@/lib/sige/queries";
import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
import { OfficialPautaEditor } from "@/components/sige/official-pauta-editor";
import { OFFICIAL_PAUTA_SUBJECTS, classifyExamCall, normalizePautaGroup } from "@/lib/sige/official-pauta";

export default async function PautasPage({ searchParams }: { searchParams: Promise<{ classGroupId?: string }> }) {
  const params = await searchParams;
  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.status === "OPEN") ?? years[0];
  const classes = year ? await getClassGroupDirectory(year.id) : [];
  const { supabase } = await requireAuthenticatedServerClient();
  const { data: pathways } = await supabase.from("academic_pathways").select("id,name,code").eq("active", true).order("code");
  const pathwayMap = new Map((pathways ?? []).map((pathway) => [pathway.id, pathway.name]));

  if (!params.classGroupId) {
    return (
      <div className="space-y-6">
        <PageHeader title="Pautas" description="Pautas oficiais da escola, editáveis no lançamento e prontas para impressão/Excel." actions={<Link href="/notas" className={buttonVariants({ variant: "outline" })}>Abrir notas</Link>} />
        {!classes.length ? (
          <div className="rounded-xl border p-8 text-sm text-muted-foreground">Não existem turmas disponíveis no ano lectivo aberto.</div>
        ) : (
          <form method="get" className="max-w-xl space-y-3 rounded-xl border p-5">
            <label htmlFor="classGroupId" className="text-sm font-medium">Turma</label>
            <select id="classGroupId" name="classGroupId" className="h-10 w-full rounded-md border bg-background px-3 text-sm" required>
              <option value="">Seleccionar turma</option>
              {classes.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.grade_level_name} · {item.name ?? item.section_code} · {item.pathway_id ? pathwayMap.get(item.pathway_id) ?? "Opção" : "Opção não definida"}
                </option>
              ))}
            </select>
            <button className={buttonVariants()} type="submit">Abrir pauta</button>
          </form>
        )}
      </div>
    );
  }

  const selectedClass = classes.find((item) => item.id === params.classGroupId);
  if (!selectedClass) redirect("/pautas");

  const pathwayName = selectedClass.pathway_id ? pathwayMap.get(selectedClass.pathway_id) ?? null : null;
  const pathwayGroup = normalizePautaGroup(pathwayName);
  const [gradebook, publishedResults, students, roster, courseOfferings, schoolResult] = await Promise.all([
    getAssessmentGradebook({ class_group_id: params.classGroupId }),
    getAcademicResultPauta({ class_group_id: params.classGroupId }),
    getStudentDirectory(),
    getClassGroupStudents(params.classGroupId),
    getCourseOfferings(params.classGroupId),
    supabase.from("schools").select("name").eq("active", true).order("created_at").limit(1).maybeSingle(),
  ]);

  const examRows = gradebook.filter((row) => row.type === "EXAM");
  const officialSubjects = pathwayGroup
    ? OFFICIAL_PAUTA_SUBJECTS[pathwayGroup]
    : courseOfferings.map((item) => ({ code: item.subject_code, name: item.subject_name, span: 3 as const }));
  const subjectByCode = new Map(courseOfferings.map((item) => [item.subject_code, item]));
  const officialPautaSubjects = officialSubjects.map((subject) => ({
    subjectCode: subject.code,
    subjectName: subject.name,
    span: subject.span,
    courseOfferingId: subjectByCode.get(subject.code)?.id ?? null,
  }));

  const studentMap = new Map(students.map((student) => [student.id, student]));
  const resultMap = new Map(
    publishedResults.map((result) => [
      `${result.student_id}:${result.course_offering_id}:${result.result_type}`,
      result,
    ]),
  );

  const rows = examRows.map((row) => {
    const student = studentMap.get(row.student_id);
    const frequency = resultMap.get(`${row.student_id}:${row.course_offering_id}:FREQUENCY`);
    const final = resultMap.get(`${row.student_id}:${row.course_offering_id}:FINAL`);
    return {
      studentId: row.student_id,
      studentNumber: row.student_number,
      studentName: row.student_name,
      gender: student?.gender ?? null,
      subjectCode: frequency?.subject_code ?? final?.subject_code ?? row.subject_name.slice(0, 3).toUpperCase(),
      subjectName: row.subject_name,
      courseOfferingId: row.course_offering_id,
      assessmentId: row.assessment_id,
      assessmentStatus: row.assessment_status,
      assessmentTitle: row.title,
      examCall: classifyExamCall(row.title),
      maxScore: row.max_score,
      examRawScore: row.raw_score,
      examResultId: row.assessment_result_id,
      examResultStatus: row.result_status,
      frequency: frequency?.display_value ?? null,
      finalValue: final?.display_value ?? null,
    };
  });

  const pautaStudents = roster.map((student) => ({
    studentId: student.student_id,
    studentNumber: student.school_number,
    studentName: student.student_name,
    gender: studentMap.get(student.student_id)?.gender ?? null,
  }));

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pauta de Exame"
        description={`${selectedClass.grade_level_name} · ${selectedClass.name ?? selectedClass.section_code} · ${pathwayName ?? "Opção não definida"} · ${year?.label ?? ""}`}
        actions={
          <div className="flex gap-2">
            <Link href={`/api/pautas/export?classGroupId=${params.classGroupId}`} className={buttonVariants({ variant: "outline" })}>Exportar Excel</Link>
            <Link href="/pautas" className={buttonVariants({ variant: "outline" })}>Outra turma</Link>
            <Link href="/notas" className={buttonVariants({ variant: "outline" })}>Notas</Link>
          </div>
        }
      />
      {!selectedClass.pathway_id ? (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 p-3 text-sm">
          Esta turma ainda não tem Opção/Grupo A ou B configurado. A pauta pode ser editada, mas a ordem curricular oficial 12A/12B só deve ser aplicada depois dessa configuração.
        </div>
      ) : null}
      {!rows.length ? (
        <div className="rounded-lg border border-muted bg-muted/20 p-3 text-sm text-muted-foreground">
          Ainda não existem avaliações de exame para esta turma. A pauta abaixo permanece disponível como modelo preenchível e imprimível.
        </div>
      ) : null}
      <OfficialPautaEditor
        schoolName={schoolResult.data?.name ?? "Escola Secundária"}
        province="Província"
        academicYear={year?.label ?? ""}
        className={selectedClass.name ?? selectedClass.section_code}
        pathwayName={pathwayName}
        subjects={officialPautaSubjects}
        students={pautaStudents}
        rows={rows}
      />
    </div>
  );
}
