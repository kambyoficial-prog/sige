"use client";

import { useMemo, useState, useTransition } from "react";
import { saveAssessmentResultAction } from "@/lib/sige/assessment-actions";
import { Button } from "@/components/ui/button";
import type { AssessmentGradebookRow } from "@sige/contracts";

export function GradebookGrid({ rows }: { rows: AssessmentGradebookRow[] }) {
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const assessments = useMemo(
    () => Array.from(new Map(rows.map((r) => [r.assessment_id, r])).values()),
    [rows],
  );
  const students = useMemo(
    () => Array.from(new Map(rows.map((r) => [r.student_id, r])).values()),
    [rows],
  );

  function key(studentId: string, assessmentId: string) {
    return `${studentId}:${assessmentId}`;
  }

  function save(row: AssessmentGradebookRow) {
    const value = drafts[key(row.student_id, row.assessment_id)];
    if (value === undefined) return;

    const parsed = value.trim() === "" ? null : Number(value);
    if (parsed !== null && !Number.isFinite(parsed)) {
      setError("Introduza uma nota numérica válida.");
      return;
    }

    setError(null);
    startTransition(async () => {
      try {
        await saveAssessmentResultAction({
          assessmentId: row.assessment_id,
          studentId: row.student_id,
          rawScore: parsed,
          status: parsed === null ? "EXCUSED" : "ENTERED",
        });
        window.location.reload();
      } catch (e) {
        setError(e instanceof Error ? e.message : "Não foi possível guardar a nota.");
      }
    });
  }

  if (!assessments.length || !students.length) {
    return <div className="rounded-xl border p-8 text-sm text-muted-foreground">Não existem avaliações/alunos neste contexto.</div>;
  }

  return (
    <div className="space-y-3">
      {error ? <div className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{error}</div> : null}
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full min-w-[760px] text-sm">
          <thead className="bg-muted/40">
            <tr className="border-b">
              <th className="sticky left-0 bg-muted/40 px-4 py-3 text-left font-medium">Aluno</th>
              {assessments.map((a) => (
                <th key={a.assessment_id} className="px-3 py-3 text-center font-medium">
                  <div>{a.title}</div>
                  <div className="text-xs font-normal text-muted-foreground">{a.type} · /{a.max_score}</div>
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
                {assessments.map((assessment) => {
                  const row = rows.find((r) => r.student_id === student.student_id && r.assessment_id === assessment.assessment_id);
                  if (!row) return <td key={assessment.assessment_id} className="px-3 py-2 text-center text-muted-foreground">—</td>;
                  const draft = drafts[key(row.student_id, row.assessment_id)];
                  const current = draft ?? (row.raw_score == null ? "" : String(row.raw_score));
                  return (
                    <td key={assessment.assessment_id} className="px-2 py-2 text-center">
                      <div className="flex items-center justify-center gap-1">
                        <input
                          aria-label={`${row.student_name} — ${row.title}`}
                          disabled={row.assessment_status !== "OPEN" || pending}
                          value={current}
                          onChange={(e) => setDrafts((d) => ({ ...d, [key(row.student_id, row.assessment_id)]: e.target.value }))}
                          onBlur={() => save(row)}
                          inputMode="decimal"
                          className="h-9 w-20 rounded-md border bg-background px-2 text-center outline-none focus:ring-2 focus:ring-ring"
                        />
                        {draft !== undefined ? <Button size="sm" variant="ghost" onClick={() => save(row)} disabled={pending}>Guardar</Button> : null}
                      </div>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
