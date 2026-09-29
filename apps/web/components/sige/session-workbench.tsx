"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import type { ClassSessionDirectory, ClassSessionRoster, TimetableEntry } from "@sige/contracts";
import { Button } from "@/components/ui/button";
import {
  closeClassSessionAction,
  openClassSessionAction,
  recordSessionAttendanceAction,
} from "@/lib/sige/session-actions";

function ActionButton({
  children,
  onClick,
  disabled,
}: {
  children: React.ReactNode;
  onClick: () => Promise<void>;
  disabled?: boolean;
}) {
  const [pending, startTransition] = useTransition();
  return (
    <Button
      type="button"
      size="sm"
      variant="outline"
      disabled={pending || disabled}
      onClick={() => startTransition(() => void onClick())}
    >
      {pending ? "A guardar…" : children}
    </Button>
  );
}

export function SessionWorkbench({
  date,
  scheduleEntries,
  sessions,
  selectedSession,
  roster,
}: {
  date: string;
  scheduleEntries: TimetableEntry[];
  sessions: ClassSessionDirectory[];
  selectedSession: ClassSessionDirectory | null;
  roster: ClassSessionRoster[];
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [lateMinutes, setLateMinutes] = useState<Record<string, string>>({});

  async function openSession(scheduleEntryId: string) {
    const result = await openClassSessionAction({ scheduleEntryId, sessionDate: date });
    if (!result.ok) {
      setError(result.code);
      return;
    }
    setError(null);
    router.refresh();
  }

  async function closeSession(classSessionId: string) {
    const result = await closeClassSessionAction({ classSessionId });
    if (!result.ok) {
      setError(result.code);
      return;
    }
    setError(null);
    router.refresh();
  }

  async function setAttendance(
    studentId: string,
    status: "PRESENT" | "ABSENT" | "EXCUSED" | "LATE",
  ) {
    if (!selectedSession) return;
    const minutes = status === "LATE" ? Number(lateMinutes[studentId] ?? "") : undefined;
    if (status === "LATE" && (!Number.isInteger(minutes) || minutes < 1)) {
      setError("Indique os minutos de atraso antes de registar.");
      return;
    }

    const result = await recordSessionAttendanceAction({
      classSessionId: selectedSession.id,
      studentId,
      status,
      ...(status === "LATE" ? { minutesLate: minutes } : {}),
    });

    if (!result.ok) {
      setError(result.code);
      return;
    }
    setError(null);
    router.refresh();
  }

  const weekday = new Date(date + "T12:00:00Z").getUTCDay();
  const isoWeekday = weekday === 0 ? 7 : weekday;
  const visibleEntries = scheduleEntries.filter((entry) => entry.day_of_week === isoWeekday);

  return (
    <div className="space-y-6">
      {error ? (
        <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">
          Operação não concluída: {error}
        </div>
      ) : null}

      <section className="rounded-xl border border-border bg-card">
        <div className="border-b border-border p-5">
          <h2 className="font-semibold">Aulas previstas</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            As sessões são abertas a partir do horário oficial da turma.
          </p>
        </div>
        <div className="divide-y divide-border">
          {visibleEntries.length === 0 ? (
            <div className="p-6 text-sm text-muted-foreground">
              Não há aulas previstas para esta turma nesta data.
            </div>
          ) : (
            visibleEntries.map((entry) => {
              const existing = sessions.find((session) => session.schedule_entry_id === entry.id);
              return (
                <div key={entry.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="font-medium">{entry.period_name} · {entry.subject_name}</div>
                    <div className="mt-1 text-sm text-muted-foreground">
                      {entry.teacher_name}{entry.room_name ? ` · Sala ${entry.room_name}` : ""}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {existing ? (
                      <span className="rounded-md bg-muted px-2.5 py-1 text-xs font-medium">
                        {existing.status === "OPEN" ? "Aberta" : existing.status === "CLOSED" ? "Fechada" : existing.status}
                      </span>
                    ) : (
                      <ActionButton onClick={() => openSession(entry.id)}>Abrir sessão</ActionButton>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </section>

      <section className="rounded-xl border border-border bg-card">
        <div className="border-b border-border p-5">
          <h2 className="font-semibold">Sessões do dia</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            O estado da sessão determina se o livro de ponto pode ser alterado.
          </p>
        </div>
        <div className="divide-y divide-border">
          {sessions.length === 0 ? (
            <div className="p-6 text-sm text-muted-foreground">Nenhuma sessão aberta ou registada.</div>
          ) : (
            sessions.map((session) => (
              <div key={session.id} className="flex flex-col gap-3 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="font-medium">
                    {session.period_name} · {session.subject_name} · {session.teacher_name}
                  </div>
                  <div className="mt-1 text-sm text-muted-foreground">
                    {session.attendance_count} lançamentos · {session.status === "OPEN" ? "em curso" : "fechada"}
                  </div>
                </div>
                <div className="flex gap-2">
                  <a
                    href={"/livro-de-ponto?date=" + date + "&class_id=" + session.class_group_id + "&session_id=" + session.id}
                    className="inline-flex h-9 items-center rounded-md border border-input px-3 text-sm font-medium hover:bg-muted"
                  >
                    Abrir livro
                  </a>
                  {session.status === "OPEN" ? (
                    <ActionButton onClick={() => closeSession(session.id)}>Fechar</ActionButton>
                  ) : null}
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      {selectedSession ? (
        <section className="rounded-xl border border-border bg-card">
          <div className="border-b border-border p-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <h2 className="font-semibold">{selectedSession.subject_name}</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  {selectedSession.period_name} · {selectedSession.teacher_name}
                </p>
              </div>
              <span className="rounded-md bg-muted px-2.5 py-1 text-xs font-medium">
                {selectedSession.status === "OPEN" ? "Sessão aberta" : "Sessão fechada"}
              </span>
            </div>
          </div>
          <div className="divide-y divide-border">
            {roster.map((student) => (
              <div key={student.student_id} className="flex flex-col gap-3 p-4 lg:grid lg:grid-cols-[minmax(220px,1fr)_auto] lg:items-center">
                <div className="min-w-0">
                  <div className="font-medium">{student.student_name}</div>
                  <div className="text-xs text-muted-foreground">
                    {student.school_number}
                    {student.attendance_status ? ` · ${student.attendance_status}` : ""}
                  </div>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  <ActionButton disabled={selectedSession.status !== "OPEN"} onClick={() => setAttendance(student.student_id, "PRESENT")}>Presente</ActionButton>
                  <ActionButton disabled={selectedSession.status !== "OPEN"} onClick={() => setAttendance(student.student_id, "ABSENT")}>Falta</ActionButton>
                  <ActionButton disabled={selectedSession.status !== "OPEN"} onClick={() => setAttendance(student.student_id, "EXCUSED")}>Justificada</ActionButton>
                  <input
                    aria-label={`Minutos de atraso de ${student.student_name}`}
                    type="number"
                    min={1}
                    max={600}
                    inputMode="numeric"
                    value={lateMinutes[student.student_id] ?? ""}
                    onChange={(event) => setLateMinutes((current) => ({ ...current, [student.student_id]: event.target.value }))}
                    placeholder="min."
                    className="h-9 w-20 rounded-md border border-input bg-background px-2 text-sm"
                    disabled={selectedSession.status !== "OPEN"}
                  />
                  <ActionButton disabled={selectedSession.status !== "OPEN"} onClick={() => setAttendance(student.student_id, "LATE")}>Atraso</ActionButton>
                </div>
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
