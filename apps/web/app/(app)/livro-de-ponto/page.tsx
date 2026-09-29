import { PageHeader } from "@/components/ui/page-header";
import { getClassGroupDirectory, getClassSessionDirectory, getClassSessionRoster, getClassTimetable } from "@/lib/sige/queries";
import { SessionWorkbench } from "@/components/sige/session-workbench";

function schoolDate() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Maputo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

export default async function LivroDePontoPage({
  searchParams,
}: {
  searchParams: Promise<{ class_id?: string; date?: string; session_id?: string }>;
}) {
  const params = await searchParams;
  const classes = await getClassGroupDirectory();
  const selectedClass = classes.find((item) => item.id === params.class_id) ?? classes[0];
  const date = /^\d{4}-\d{2}-\d{2}$/.test(params.date ?? "") ? params.date! : schoolDate();

  const [scheduleEntries, sessions] = selectedClass
    ? await Promise.all([
        getClassTimetable(selectedClass.id),
        getClassSessionDirectory({ class_group_id: selectedClass.id, session_date: date }),
      ])
    : [[], []];

  const selectedSession = params.session_id
    ? sessions.find((session) => session.id === params.session_id) ?? null
    : sessions.find((session) => session.status === "OPEN") ?? sessions[0] ?? null;

  const roster = selectedSession ? await getClassSessionRoster(selectedSession.id) : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Livro de ponto"
        description="Sessões de aula e registo de frequência ligados ao horário oficial."
      />

      <form method="get" className="grid gap-3 rounded-xl border border-border bg-card p-4 sm:grid-cols-[minmax(0,1fr)_180px_auto] sm:items-end">
        <label className="space-y-1.5">
          <span className="text-sm font-medium">Turma</span>
          <select
            name="class_id"
            defaultValue={selectedClass?.id ?? ""}
            className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
          >
            {classes.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name || item.section_code} · {item.grade_level_name}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1.5">
          <span className="text-sm font-medium">Data</span>
          <input
            type="date"
            name="date"
            defaultValue={date}
            className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
          />
        </label>
        <button
          type="submit"
          className="inline-flex h-10 items-center justify-center rounded-md bg-foreground px-4 text-sm font-medium text-background"
        >
          Consultar
        </button>
      </form>

      {!selectedClass ? (
        <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
          Ainda não existem turmas disponíveis para operar o livro de ponto.
        </div>
      ) : (
        <SessionWorkbench
          date={date}
          scheduleEntries={scheduleEntries}
          sessions={sessions}
          selectedSession={selectedSession}
          roster={roster}
        />
      )}
    </div>
  );
}
