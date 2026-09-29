import type { StudentTimetableEntry, TeacherTimetableEntry, TimetableEntry } from "@sige/contracts";

type GridEntry = TimetableEntry | TeacherTimetableEntry | StudentTimetableEntry;

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

export function TimetableGrid({ entries }: { entries: GridEntry[] }) {
  const periods = new Map<number, GridEntry[]>();
  for (const entry of entries) {
    const current = periods.get(entry.period_ordinal) ?? [];
    current.push(entry);
    periods.set(entry.period_ordinal, current);
  }

  const orderedPeriods = [...periods.entries()].sort(([a], [b]) => a - b);

  if (!orderedPeriods.length) {
    return (
      <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
        Ainda não existem entradas de horário para este contexto.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-border bg-card">
      <div className="min-w-[900px]">
        <div className="grid grid-cols-[120px_repeat(5,minmax(150px,1fr))] border-b border-border bg-muted/30 text-sm font-medium">
          <div className="p-3">Período</div>
          {days.map((day) => (
            <div key={day.value} className="border-l border-border p-3">{day.label}</div>
          ))}
        </div>

        {orderedPeriods.map(([ordinal, periodEntries]) => {
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
                          {"class_name" in lesson && lesson.class_name
                            ? lesson.class_name
                            : lesson.teacher_name}
                        </div>
                        {lesson.room_name ? (
                          <div className="mt-2 text-xs text-muted-foreground">Sala {lesson.room_name}</div>
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
  );
}
