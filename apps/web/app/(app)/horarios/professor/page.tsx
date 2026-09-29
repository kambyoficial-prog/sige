import Link from "next/link";
import type { TeacherTimetableEntry } from "@sige/contracts";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { TimetableGrid } from "@/components/sige/timetable-grid";
import { getTeacherDirectory, getTeacherTimetable } from "@/lib/sige/queries";

export default async function TeacherTimetablePage({
  searchParams,
}: {
  searchParams: Promise<{ teacher_id?: string }>;
}) {
  const params = await searchParams;
  const teachers = await getTeacherDirectory();
  const selected = teachers.find((item) => item.id === params.teacher_id) ?? teachers[0];
  const entries: TeacherTimetableEntry[] = selected
    ? await getTeacherTimetable(selected.id)
    : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Horário do professor"
        description="Carga semanal do docente, turma, disciplina, período e sala a partir do horário oficial."
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
          className="rounded-lg border border-foreground bg-foreground px-3 py-2 text-sm text-background"
        >
          Por professor
        </Link>
        <Link
          href="/horarios/aluno"
          className="rounded-lg border border-border bg-card px-3 py-2 text-sm hover:bg-muted"
        >
          Por aluno
        </Link>
      </div>

      {!selected ? (
        <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
          Ainda não existem professores disponíveis.
        </div>
      ) : (
        <>
          <form method="get" className="rounded-xl border border-border bg-card p-4">
            <label className="block max-w-xl space-y-1.5">
              <span className="text-sm font-medium">Professor</span>
              <select
                name="teacher_id"
                defaultValue={selected.id}
                className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
              >
                {teachers.map((teacher) => (
                  <option key={teacher.id} value={teacher.id}>
                    {teacher.full_name} · {teacher.employee_code}
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
                  Código {selected.employee_code}
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
