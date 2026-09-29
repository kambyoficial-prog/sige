import Link from "next/link";
import type { StudentTimetableEntry } from "@sige/contracts";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { TimetableGrid } from "@/components/sige/timetable-grid";
import { getStudentDirectory, getStudentTimetable } from "@/lib/sige/queries";

export default async function StudentTimetablePage({
  searchParams,
}: {
  searchParams: Promise<{ student_id?: string }>;
}) {
  const params = await searchParams;
  const students = await getStudentDirectory();
  const selected = students.find((item) => item.id === params.student_id) ?? students[0];
  const entries: StudentTimetableEntry[] = selected
    ? await getStudentTimetable(selected.id)
    : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Horário do aluno"
        description="Horário efetivo do aluno a partir da sua matrícula e colocação temporal na turma."
      />

      <div className="flex flex-wrap items-center gap-2">
        <Link
          href="/horarios"
          className="rounded-lg border border-border bg-card px-3 py-2 text-sm hover:bg-muted"
        >
          Por turma
        </Link>
        <Link
          href="/horarios/professor"
          className="rounded-lg border border-border bg-card px-3 py-2 text-sm hover:bg-muted"
        >
          Por professor
        </Link>
        <Link
          href="/horarios/aluno"
          className="rounded-lg border border-foreground bg-foreground px-3 py-2 text-sm text-background"
        >
          Por aluno
        </Link>
      </div>

      {!selected ? (
        <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
          Ainda não existem alunos disponíveis.
        </div>
      ) : (
        <>
          <form method="get" className="rounded-xl border border-border bg-card p-4">
            <label className="block max-w-xl space-y-1.5">
              <span className="text-sm font-medium">Aluno</span>
              <select
                name="student_id"
                defaultValue={selected.id}
                className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
              >
                {students.map((student) => (
                  <option key={student.id} value={student.id}>
                    {student.full_name} · {student.school_number}
                  </option>
                ))}
              </select>
            </label>
          </form>

          <div className="rounded-xl border border-border bg-card p-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-semibold">{selected.full_name}</h2>
                <p className="text-sm text-muted-foreground">
                  {selected.school_number}
                  {selected.class_name ? ` · ${selected.class_name}` : ""}
                </p>
              </div>
              <Badge variant="secondary">{entries.length} aulas semanais</Badge>
            </div>
          </div>

          <TimetableGrid entries={entries} />
        </>
      )}
    </div>
  );
}
