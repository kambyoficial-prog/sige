import { redirect } from "next/navigation";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import {
  getAcademicResultPauta,
  getAcademicYearOptions,
  getAssessmentGradebook,
  getClassGroupDirectory,
  getStudentDirectory,
} from "@/lib/sige/queries";
import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
import { OfficialPautaEditor } from "@/components/sige/official-pauta-editor";

export default async function PautasPage({
  searchParams,
}: {
  searchParams: Promise<{ classGroupId?: string }>;
}) {
  const params = await searchParams;
  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.status === "OPEN") ?? years[0];
  const classes = year ? await getClassGroupDirectory(year.id) : [];

  if (!params.classGroupId) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Pautas"
          description="Pautas oficiais da escola, editáveis no lançamento e prontas para impressão."
          actions={<Link href="/notas" className={buttonVariants({ variant: "outline" })}>Abrir notas</Link>}
        />
        {!classes.length ? (
          <div className="rounded-xl border p-8 text-sm text-muted-foreground">
            Não existem turmas disponíveis no ano lectivo aberto.
          </div>
        ) : (
          <form method="get" className="max-w-xl space-y-3 rounded-xl border p-5">
            <label htmlFor="classGroupId" className="text-sm font-medium">Turma</label>
            <select id="classGroupId" name="classGroupId" className="h-10 w-full rounded-md border bg-background px-3 text-sm" required>
              <option value="">Seleccionar turma</option>
              {classes.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.grade_level_name} · {item.name ?? item.section_code} · {item.pathway_name ?? "Opção não definida"}
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

  const [gradebook, publishedResults, students, schoolResult] = await Promise.all([
    getAssessmentGradebook({ class_group_id: params.classGroupId }),
    getAcademicResultPauta({ class_group_id: params.classGroupId }),
    getStudentDirectory(),
    (async () => {
      const { supabase } = await requireAuthenticatedServerClient();
      return supabase.from("schools").select("name").eq("active", true).order("created_at").limit(1).maybeSingle();
    })(),
  ]);

  const examRows = gradebook.filter((row) => row.type === "EXAM");
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
      subjectCode: row.subject_name === "Língua Portuguesa" ? "POR" : row.subject_name.slice(0, 3).toUpperCase(),
      subjectName: row.subject_name,
      courseOfferingId: row.course_offering_id,
      assessmentId: row.assessment_id,
      assessmentStatus: row.assessment_status,
      maxScore: row.max_score,
      examRawScore: row.raw_score,
      examResultId: row.assessment_result_id,
      examResultStatus: row.result_status,
      frequency: frequency?.display_value ?? null,
      finalValue: final?.display_value ?? null,
    };
  });

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pauta de Exame"
        description={`${selectedClass.grade_level_name} · ${selectedClass.name ?? selectedClass.section_code} · ${selectedClass.pathway_name ?? "Opção não definida"} · ${year?.label ?? ""}`}
        actions={
          <div className="flex gap-2">
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
        <div className="rounded-xl border p-8 text-sm text-muted-foreground">
          Ainda não existem avaliações de exame para esta turma. A pauta oficial será preenchida automaticamente quando as avaliações forem criadas.
        </div>
      ) : (
        <OfficialPautaEditor
          schoolName={schoolResult.data?.name ?? "Escola Secundária"}
          province="Província"
          academicYear={year?.label ?? ""}
          gradeName={selectedClass.grade_level_name}
          className={selectedClass.name ?? selectedClass.section_code}
          pathwayName={selectedClass.pathway_name}
          rows={rows}
        />
      )}
    </div>
  );
}
