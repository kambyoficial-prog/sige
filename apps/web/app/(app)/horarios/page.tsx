import Link from "next/link";
import type { TimetableEntry } from "@sige/contracts";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { getClassGroupDirectory, getClassTimetable } from "@/lib/sige/queries";

const days = [
  { value: 1, label: "Segunda" },
  { value: 2, label: "Terça" },
  { value: 3, label: "Quarta" },
  { value: 4, label: "Quinta" },
  { value: 5, label: "Sexta" },
];

function formatTime(value: string) {
  return value.slice(0, 5);
}

function groupByPeriod(entries: TimetableEntry[]) {
  const map = new Map<number, TimetableEntry[]>();
  for (const entry of entries) {
    const current = map.get(entry.period_ordinal) ?? [];
    current.push(entry);
    map.set(entry.period_ordinal, current);
  }
  return [...map.entries()].sort(([a], [b]) => a - b);
}

export default async function TimetablesPage({
  searchParams,
}: {
  searchParams: Promise<{ class_id?: string }>;
}) {
  const params = await searchParams;
  const classes = await getClassGroupDirectory();
  const selected = classes.find((item) => item.id === params.class_id) ?? classes[0];
  const entries = selected ? await getClassTimetable(selected.id) : [];
  const periods = groupByPeriod(entries);

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
                  href={`/horarios?class_id=${item.id}`}
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

          <div className="rounded-xl border border-border bg-card">
            <div className="flex flex-col gap-3 border-b border-border p-5 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-semibold">{selected.name || selected.section_code}</h2>
                <p className="text-sm text-muted-foreground">
                  {selected.grade_level_name} · {selected.academic_year_label}
                  {selected.shift ? ` · ${selected.shift}` : ""}
                </p>
              </div>
              <Badge variant="secondary">{entries.length} aulas configuradas</Badge>
            </div>

            {periods.length === 0 ? (
              <div className="p-8 text-sm text-muted-foreground">
                Esta turma ainda não possui entradas de horário.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <div className="min-w-[900px]">
                  <div className="grid grid-cols-[120px_repeat(5,minmax(150px,1fr))] border-b border-border bg-muted/30 text-sm font-medium">
                    <div className="p-3">Período</div>
                    {days.map((day) => (
                      <div key={day.value} className="border-l border-border p-3">
                        {day.label}
                      </div>
                    ))}
                  </div>

                  {periods.map(([ordinal, periodEntries]) => {
                    const reference = periodEntries[0];
                    return (
                      <div
                        key={ordinal}
                        className="grid grid-cols-[120px_repeat(5,minmax(150px,1fr))] border-b border-border last:border-b-0"
                      >
                        <div className="p-3">
                          <div className="font-medium">{reference.period_name}</div>
                          <div className="text-xs text-muted-foreground">
                            {formatTime(reference.starts_at)}–{formatTime(reference.ends_at)}
                          </div>
                        </div>

                        {days.map((day) => {
                          const lesson = periodEntries.find((entry) => entry.day_of_week === day.value);
                          return (
                            <div key={day.value} className="min-h-24 border-l border-border p-2">
                              {lesson ? (
                                <div className="rounded-lg border border-border bg-background p-3">
                                  <div className="font-medium">{lesson.subject_name}</div>
                                  <div className="mt-1 text-xs text-muted-foreground">
                                    {lesson.teacher_name}
                                  </div>
                                  {lesson.room_name ? (
                                    <div className="mt-2 text-xs text-muted-foreground">
                                      Sala {lesson.room_name}
                                    </div>
                                  ) : null}
                                </div>
                              ) : (
                                <span className="text-xs text-muted-foreground">Livre</span>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
