import Link from "next/link";
import type { TimetableEntry } from "@sige/contracts";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { TimetableGrid } from "@/components/sige/timetable-grid";
import { getClassGroupDirectory, getClassTimetable } from "@/lib/sige/queries";

export default async function TimetablesPage({
  searchParams,
}: {
  searchParams: Promise<{ class_id?: string }>;
}) {
  const params = await searchParams;
  const classes = await getClassGroupDirectory();
  const selected = classes.find((item) => item.id === params.class_id) ?? classes[0];
  const entries: TimetableEntry[] = selected ? await getClassTimetable(selected.id) : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Horários"
        description="Distribuição semanal das aulas por turma, período, docente e sala."
      />

      {!selected ? (
        <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
          Ainda não existem turmas disponíveis para montar um horário.
        </div>
      ) : (
        <>
          <div className="flex flex-wrap gap-2">
            {classes.map((item) => {
              const active = item.id === selected.id;
              return (
                <Link
                  key={item.id}
                  href={"/horarios?class_id=" + item.id}
                  className={[
                    "rounded-lg border px-3 py-2 text-sm transition-colors",
                    active
                      ? "border-foreground bg-foreground text-background"
                      : "border-border bg-card hover:bg-muted",
                  ].join(" ")}
                >
                  {item.name || item.section_code}
                </Link>
              );
            })}
          </div>

          <div className="rounded-xl border border-border bg-card p-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-semibold">{selected.name || selected.section_code}</h2>
                <p className="text-sm text-muted-foreground">
                  {selected.grade_level_name} · {selected.academic_year_label}
                  {selected.shift ? " · " + selected.shift : ""}
                </p>
              </div>
              <Badge variant="secondary">{entries.length} aulas configuradas</Badge>
            </div>
          </div>

          <TimetableGrid entries={entries} />
        </>
      )}
    </div>
  );
}
