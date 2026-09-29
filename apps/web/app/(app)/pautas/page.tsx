import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getAcademicResultPauta } from "@/lib/sige/queries";

export default async function PautasPage({
  searchParams,
}: {
  searchParams: Promise<{ classGroupId?: string; periodId?: string; resultType?: string }>;
}) {
  const params = await searchParams;
  const rows = await getAcademicResultPauta({
    ...(params.classGroupId ? { class_group_id: params.classGroupId } : {}),
    ...(params.periodId ? { assessment_period_id: params.periodId } : {}),
    ...(params.resultType ? { result_type: params.resultType } : {}),
  });

  const subjects = Array.from(new Map(rows.map((r) => [r.course_offering_id, r])).values());
  const students = Array.from(new Map(rows.map((r) => [r.student_id, r])).values());

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pautas"
        description="Projeção dos resultados académicos publicados. A pauta é somente leitura."
        actions={<Link href="/notas" className={buttonVariants({ variant: "outline" })}>Abrir notas</Link>}
      />

      {!rows.length ? (
        <div className="rounded-xl border p-8 text-sm text-muted-foreground">
          Ainda não existem resultados publicados para este contexto.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border">
          <table className="w-full min-w-[900px] text-sm">
            <thead className="bg-muted/40">
              <tr className="border-b">
                <th className="sticky left-0 bg-muted/40 px-4 py-3 text-left">Aluno</th>
                {subjects.map((s) => (
                  <th key={s.course_offering_id} className="px-3 py-3 text-center">
                    <div>{s.subject_name}</div>
                    <div className="text-xs font-normal text-muted-foreground">{s.subject_code}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {students.map((student) => (
                <tr key={student.student_id} className="border-b last:border-0">
                  <td className="sticky left-0 bg-background px-4 py-3">
                    <div className="font-medium">{student.student_name}</div>
                    <div className="text-xs text-muted-foreground">{student.student_number}</div>
                  </td>
                  {subjects.map((subject) => {
                    const result = rows.find(
                      (r) => r.student_id === student.student_id && r.course_offering_id === subject.course_offering_id,
                    );
                    return (
                      <td key={subject.course_offering_id} className="px-3 py-3 text-center">
                        {result?.display_value ?? "—"}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {rows.length ? (
        <p className="text-xs text-muted-foreground">
          Fonte: resultados com estado PUBLISHED. Regra aplicada: {rows[0]?.rule_version}.
        </p>
      ) : null}
    </div>
  );
}
