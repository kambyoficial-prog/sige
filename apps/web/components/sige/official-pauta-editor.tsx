"use client";

import { useMemo, useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { PrintButton } from "@/components/finance/print-button";
import { correctPublishedResultAction, saveAssessmentResultAction } from "@/lib/sige/assessment-actions";

type PautaRow = {
  studentId: string;
  studentNumber: string;
  studentName: string;
  gender: string | null;
  subjectCode: string;
  subjectName: string;
  courseOfferingId: string;
  assessmentId: string;
  assessmentStatus: string;
  maxScore: number | null;
  examRawScore: number | null;
  examResultId: string | null;
  examResultStatus: string | null;
  frequency: number | null;
  finalValue: number | null;
};

type Props = {
  schoolName: string;
  province: string;
  academicYear: string;
  gradeName: string;
  className: string;
  pathwayName: string | null;
  rows: PautaRow[];
};

const SUBJECT_ORDER: Record<string, string[]> = {
  A: ["POR", "ING", "FIL", "MAT", "FRA", "HIS", "GEO", "TIC"],
  B: ["POR", "ING", "FIL", "MAT", "BIO", "QUI", "FIS", "TIC"],
};

function normalizeGender(value: string | null) {
  if (!value) return "—";
  const v = value.toUpperCase();
  if (v.startsWith("F")) return "M";
  if (v.startsWith("M")) return "H";
  return value;
}

function pathwayCode(name: string | null) {
  if (!name) return "";
  if (/Grupo A/i.test(name)) return "A";
  if (/Grupo B/i.test(name)) return "B";
  return "";
}

function display(value: number | null) {
  return value == null ? "—" : String(Math.round(value));
}

export function OfficialPautaEditor(props: Props) {
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const subjects = useMemo(() => {
    const code = pathwayCode(props.pathwayName);
    const preferred = SUBJECT_ORDER[code] ?? [];
    const unique = new Map<string, PautaRow>();
    for (const row of props.rows) {
      if (!unique.has(row.courseOfferingId)) unique.set(row.courseOfferingId, row);
    }
    return [...unique.values()].sort((a, b) => {
      const ai = preferred.indexOf(a.subjectCode);
      const bi = preferred.indexOf(b.subjectCode);
      if (ai === -1 && bi === -1) return a.subjectName.localeCompare(b.subjectName);
      if (ai === -1) return 1;
      if (bi === -1) return -1;
      return ai - bi;
    });
  }, [props.rows, props.pathwayName]);

  const students = useMemo(
    () => [...new Map(props.rows.map((r) => [r.studentId, r])).values()].sort((a, b) => a.studentName.localeCompare(b.studentName)),
    [props.rows],
  );

  const byKey = useMemo(
    () => new Map(props.rows.map((r) => [`${r.studentId}:${r.courseOfferingId}`, r])),
    [props.rows],
  );

  function save(row: PautaRow) {
    const key = `${row.studentId}:${row.courseOfferingId}`;
    const value = drafts[key] ?? (row.examRawScore == null ? "" : String(row.examRawScore));
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0 || parsed > (row.maxScore ?? 20)) {
      setError(`Nota inválida para ${row.studentName} — ${row.subjectName}.`);
      return;
    }

    setError(null);
    setSaved(null);
    startTransition(async () => {
      try {
        if (row.examResultStatus === "PUBLISHED" && row.examResultId) {
          const reason = reasons[key]?.trim();
          if (!reason || reason.length < 5) {
            setError("Para corrigir uma nota publicada, indique o motivo da correção.");
            return;
          }
          await correctPublishedResultAction({
            assessmentResultId: row.examResultId,
            rawScore: parsed,
            status: "PUBLISHED",
            reason,
          });
        } else {
          await saveAssessmentResultAction({
            assessmentId: row.assessmentId,
            studentId: row.studentId,
            rawScore: parsed,
            status: "ENTERED",
          });
        }
        setDrafts((current) => {
          const next = { ...current };
          delete next[key];
          return next;
        });
        setReasons((current) => {
          const next = { ...current };
          delete next[key];
          return next;
        });
        setSaved(key);
        window.location.reload();
      } catch (e) {
        setError(e instanceof Error ? e.message : "Não foi possível guardar a nota.");
      }
    });
  }

  const statistics = useMemo(() => {
    const buckets = [
      { label: "0 – 5,9", min: 0, max: 5.9 },
      { label: "6 – 8,9", min: 6, max: 8.9 },
      { label: "9 – 13,9", min: 9, max: 13.9 },
      { label: "14 – 16,9", min: 14, max: 16.9 },
      { label: "17 – 20", min: 17, max: 20 },
    ];
    return buckets.map((bucket) => ({
      ...bucket,
      M: students.filter((s) => normalizeGender(s.gender) === "M").filter((s) => {
        const row = props.rows.find((r) => r.studentId === s.studentId);
        return row?.finalValue != null && row.finalValue >= bucket.min && row.finalValue <= bucket.max;
      }).length,
      H: students.filter((s) => normalizeGender(s.gender) === "H").filter((s) => {
        const row = props.rows.find((r) => r.studentId === s.studentId);
        return row?.finalValue != null && row.finalValue >= bucket.min && row.finalValue <= bucket.max;
      }).length,
    }));
  }, [students, props.rows]);

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3 print:hidden">
        <div>
          <div className="text-sm font-medium">Pauta de Exame · {props.pathwayName ?? "Opção não definida"}</div>
          <div className="text-xs text-muted-foreground">
            As notas de exame são editáveis enquanto a avaliação estiver aberta. Resultados publicados usam o fluxo de correção auditada.
          </div>
        </div>
        <PrintButton />
      </div>

      {error ? <div className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive print:hidden">{error}</div> : null}
      {saved ? <div className="rounded-md border border-emerald-500/30 bg-emerald-500/5 p-3 text-sm text-emerald-700 print:hidden">Alteração guardada.</div> : null}

      <section className="official-pauta rounded-none border bg-white text-black">
        <header className="border-b px-4 py-5 text-center">
          <div className="text-[11px] font-semibold uppercase">República de Moçambique</div>
          <div className="text-[11px]">{props.province}</div>
          <div className="text-[11px] font-semibold">Direcção Provincial da Educação</div>
          <div className="mt-3 text-sm font-bold uppercase">
            {props.schoolName}
          </div>
          <div className="mt-1 text-sm font-bold">12.ª Classe · {props.pathwayName ?? "Opção"}</div>
          <div className="text-sm font-bold">PAUTA DE EXAME · {props.academicYear}</div>
          <div className="mt-1 text-xs">Turma: {props.className}</div>
        </header>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[1500px] border-collapse text-[10px]">
            <thead>
              <tr>
                <th rowSpan={2} className="border px-2 py-1">N.º</th>
                <th rowSpan={2} className="border px-2 py-1">Código</th>
                <th rowSpan={2} className="border px-2 py-1 text-left">Nome do Aluno</th>
                <th rowSpan={2} className="border px-2 py-1">Género</th>
                <th rowSpan={2} className="border px-2 py-1">Turma</th>
                {subjects.map((subject) => (
                  <th key={subject.courseOfferingId} colSpan={3} className="border px-1 py-1 text-center">{subject.subjectName}</th>
                ))}
                <th rowSpan={2} className="border px-2 py-1">Média</th>
                <th rowSpan={2} className="border px-2 py-1">Resultado Final</th>
              </tr>
              <tr>
                {subjects.map((subject) => (
                  <th key={subject.courseOfferingId} colSpan={3} className="border px-1 py-1">
                    <span>Frequênc.</span> · <span>1ª/2ª ch</span> · <span>Média</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {students.map((student, index) => {
                const studentRows = subjects.map((subject) => byKey.get(`${student.studentId}:${subject.courseOfferingId}`));
                const finalValues = studentRows.map((r) => r?.finalValue).filter((v): v is number => v != null);
                const global = finalValues.length ? Math.round(finalValues.reduce((a, b) => a + b, 0) / finalValues.length) : null;
                const hasFailed = studentRows.some((r) => r?.finalValue != null && r.finalValue < 10);
                return (
                  <tr key={student.studentId}>
                    <td className="border px-2 py-1 text-center">{index + 1}</td>
                    <td className="border px-2 py-1 text-center">{student.studentNumber}</td>
                    <td className="border px-2 py-1">{student.studentName}</td>
                    <td className="border px-2 py-1 text-center">{normalizeGender(student.gender)}</td>
                    <td className="border px-2 py-1 text-center">{props.className}</td>
                    {studentRows.map((row, subjectIndex) => {
                      if (!row) {
                        return <td key={subjects[subjectIndex]?.courseOfferingId ?? `subject-${subjectIndex}`} colSpan={3} className="border px-1 py-1 text-center">—</td>;
                      }
                      const key = `${row.studentId}:${row.courseOfferingId}`;
                      const draft = drafts[key];
                      const current = draft ?? (row.examRawScore == null ? "" : String(row.examRawScore));
                      const editable = row.assessmentStatus === "OPEN" || row.examResultStatus === "PUBLISHED";
                      return (
                        <td key={row.courseOfferingId} colSpan={3} className="border px-1 py-1">
                          <div className="grid grid-cols-3 items-center gap-1">
                            <span className="text-center">{display(row.frequency)}</span>
                            <div className="text-center">
                              <input
                                aria-label={`${student.studentName} — ${row.subjectName} — exame`}
                                value={current}
                                disabled={pending || !editable}
                                onChange={(e) => setDrafts((d) => ({ ...d, [key]: e.target.value }))}
                                inputMode="decimal"
                                className="h-7 w-12 border border-black/30 bg-white text-center text-[10px] outline-none focus:ring-1 focus:ring-black disabled:bg-black/5"
                              />
                              {draft !== undefined ? (
                                <Button size="sm" variant="ghost" className="h-6 px-1 text-[9px]" onClick={() => save(row)} disabled={pending}>
                                  Guardar
                                </Button>
                              ) : null}
                              {row.examResultStatus === "PUBLISHED" ? (
                                <input
                                  aria-label={`Motivo da correção — ${student.studentName} — ${row.subjectName}`}
                                  value={reasons[key] ?? ""}
                                  onChange={(e) => setReasons((d) => ({ ...d, [key]: e.target.value }))}
                                  placeholder="Motivo"
                                  className="mt-1 h-6 w-full border border-black/20 px-1 text-[9px] print:hidden"
                                />
                              ) : null}
                            </div>
                            <span className="text-center font-semibold">{display(row.finalValue)}</span>
                          </div>
                        </td>
                      );
                    })}
                    <td className="border px-2 py-1 text-center font-semibold">{display(global)}</td>
                    <td className="border px-2 py-1 text-center font-semibold">{global == null ? "—" : hasFailed ? "Reprovado" : "Aprovado"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="grid grid-cols-2 gap-6 border-t p-4 text-[10px]">
          <div>
            <div className="font-semibold">Legenda</div>
            <p>c) Concluiu · d) Não faz a disciplina · A Ausente · F Fraude · Exc Excluído.</p>
          </div>
          <div className="text-right">
            <div>O Presidente do Conselho de Exame</div>
            <div className="mt-8 border-t border-black/50 pt-1">Assinatura</div>
          </div>
        </div>
      </section>

      <section className="official-pauta border bg-white p-4 text-black print:break-before-page">
        <h2 className="mb-3 text-center text-xs font-bold uppercase">Mapa de Aproveitamento Pedagógico</h2>
        <table className="w-full border-collapse text-[10px]">
          <thead>
            <tr>
              <th className="border px-2 py-1 text-left">Escala de notas</th>
              <th className="border px-2 py-1">M</th>
              <th className="border px-2 py-1">H</th>
              <th className="border px-2 py-1">HM</th>
            </tr>
          </thead>
          <tbody>
            {statistics.map((row) => (
              <tr key={row.label}>
                <td className="border px-2 py-1">{row.label}</td>
                <td className="border px-2 py-1 text-center">{row.M}</td>
                <td className="border px-2 py-1 text-center">{row.H}</td>
                <td className="border px-2 py-1 text-center">{row.M + row.H}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <style jsx global>{`
        @media print {
          @page { size: A3 landscape; margin: 8mm; }
          body { background: white !important; }
          .official-pauta { break-inside: avoid; box-shadow: none !important; }
          .official-pauta input { border: 0 !important; background: transparent !important; }
          .official-pauta button, .official-pauta input[placeholder="Motivo"] { display: none !important; }
        }
      `}</style>
    </div>
  );
}
