"use client";

import { useMemo, useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { PrintButton } from "@/components/finance/print-button";
import { correctPublishedResultAction, saveAssessmentResultAction } from "@/lib/sige/assessment-actions";
import {
  PAUTA_BANDS,
  buildOverallPautaStats,
  buildPautaSubjectStats,
} from "@/lib/sige/official-pauta";

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
  assessmentTitle: string | null;
  examCall: 1 | 2;
  maxScore: number | null;
  examRawScore: number | null;
  examResultId: string | null;
  examResultStatus: string | null;
  frequency: number | null;
  finalValue: number | null;
};

export type PautaSubject = {
  courseOfferingId: string | null;
  subjectCode: string;
  subjectName: string;
  span: 1 | 3;
};

type PautaStudent = {
  studentId: string;
  studentNumber: string;
  studentName: string;
  gender: string | null;
};

type Props = {
  schoolName: string;
  province: string;
  academicYear: string;
  className: string;
  pathwayName: string | null;
  subjects: PautaSubject[];
  students: PautaStudent[];
  rows: PautaRow[];
};

function normalizeGender(value: string | null) {
  if (!value) return null;
  const v = value.toUpperCase();
  if (v.startsWith("F")) return "M" as const;
  if (v.startsWith("M")) return "H" as const;
  if (v.startsWith("H")) return "H" as const;
  return null;
}

function display(value: number | null) {
  return value == null ? "—" : String(Math.round(value));
}

function percent(value: number | null) {
  return value == null ? "—" : `${value.toFixed(1)}%`;
}

export function OfficialPautaEditor(props: Props) {
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const students = useMemo(
    () => [...props.students].sort((a, b) => a.studentName.localeCompare(b.studentName)),
    [props.students],
  );

  const byKey = useMemo(
    () => new Map(props.rows.map((row) => [`${row.studentId}:${row.courseOfferingId}`, row])),
    [props.rows],
  );

  const subjectStats = useMemo(
    () =>
      buildPautaSubjectStats(
        students.map((student) => ({ studentId: student.studentId, gender: normalizeGender(student.gender) })),
        props.rows.map((row) => ({
          studentId: row.studentId,
          subjectCode: row.subjectCode,
          frequency: row.frequency,
          examCall: row.examCall,
          examScore: row.examRawScore,
        })),
        props.subjects.map((subject) => ({ code: subject.subjectCode, name: subject.subjectName, span: subject.span })),
      ),
    [students, props.rows, props.subjects],
  );

  const overallStats = useMemo(
    () =>
      buildOverallPautaStats(
        students.map((student) => ({ studentId: student.studentId, gender: normalizeGender(student.gender) })),
        props.rows.map((row) => ({
          studentId: row.studentId,
          subjectCode: row.subjectCode,
          frequency: row.frequency,
          examCall: row.examCall,
          examScore: row.examRawScore,
        })),
      ),
    [students, props.rows],
  );

  function save(row: PautaRow) {
    const key = `${row.studentId}:${row.courseOfferingId}`;
    const raw = drafts[key] ?? (row.examRawScore == null ? "" : String(row.examRawScore));
    const parsed = Number(raw);

    if (!Number.isFinite(parsed) || parsed < 0 || parsed > (row.maxScore ?? 20)) {
      setError(`Nota inválida para ${row.studentName} — ${row.subjectName}.`);
      return;
    }

    setError(null);
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
        window.location.reload();
      } catch (e) {
        setError(e instanceof Error ? e.message : "Não foi possível guardar a nota.");
      }
    });
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3 print:hidden">
        <div>
          <div className="text-sm font-medium">Pauta de Exame · {props.pathwayName ?? "Opção não definida"}</div>
          <div className="text-xs text-muted-foreground">Modelo oficial editável; correcções publicadas ficam auditadas.</div>
        </div>
        <PrintButton />
      </div>

      {error ? <div className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive print:hidden">{error}</div> : null}

      <section className="official-pauta rounded-none border bg-white text-black">
        <header className="border-b px-4 py-5 text-center">
          <div className="text-[11px] font-semibold uppercase">República de Moçambique</div>
          <div className="text-[11px]">{props.province}</div>
          <div className="text-[11px] font-semibold">Direcção Provincial da Educação</div>
          <div className="mt-3 text-sm font-bold uppercase">{props.schoolName}</div>
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
                {props.subjects.map((subject) => (
                  <th key={subject.subjectCode} colSpan={subject.span} className="border px-1 py-1 text-center">{subject.subjectName}</th>
                ))}
                <th rowSpan={2} className="border px-2 py-1">Média</th>
                <th colSpan={2} className="border px-2 py-1">RESULTADO FINAL</th>
              </tr>
              <tr>
                {props.subjects.map((subject) =>
                  subject.span === 3 ? (
                    <th key={subject.subjectCode} colSpan={3} className="border px-1 py-1">Frequênc. · 1ª/2ª ch · Média</th>
                  ) : (
                    <th key={subject.subjectCode} className="border px-1 py-1">Resultado</th>
                  ),
                )}
                <th className="border px-1 py-1">Aprovado</th>
                <th className="border px-1 py-1">Reprovado</th>
              </tr>
            </thead>
            <tbody>
              {students.map((student, index) => {
                const subjectRows = props.subjects.map((subject) =>
                  subject.courseOfferingId ? byKey.get(`${student.studentId}:${subject.courseOfferingId}`) : undefined,
                );
                const finalValues = subjectRows.map((row) => row?.finalValue).filter((value): value is number => value != null);
                const global = finalValues.length ? Math.round(finalValues.reduce((sum, value) => sum + value, 0) / finalValues.length) : null;
                const hasFailed = subjectRows.some((row) => row?.finalValue != null && row.finalValue < 10);

                return (
                  <tr key={student.studentId}>
                    <td className="border px-2 py-1 text-center">{index + 1}</td>
                    <td className="border px-2 py-1 text-center">{student.studentNumber}</td>
                    <td className="border px-2 py-1">{student.studentName}</td>
                    <td className="border px-2 py-1 text-center">{normalizeGender(student.gender) ?? "—"}</td>
                    <td className="border px-2 py-1 text-center">{props.className}</td>
                    {subjectRows.map((row, subjectIndex) => {
                      const subject = props.subjects[subjectIndex];
                      if (!row) return <td key={subject.subjectCode} colSpan={subject.span} className="border px-1 py-1 text-center">—</td>;
                      if (subject.span === 1) return <td key={subject.subjectCode} className="border px-1 py-1 text-center">{display(row.finalValue)}</td>;

                      const key = `${row.studentId}:${row.courseOfferingId}`;
                      const draft = drafts[key];
                      const current = draft ?? (row.examRawScore == null ? "" : String(row.examRawScore));
                      const editable = row.assessmentStatus === "OPEN" || row.examResultStatus === "PUBLISHED";

                      return (
                        <td key={subject.subjectCode} colSpan={3} className="border px-1 py-1">
                          <div className="grid grid-cols-3 items-center gap-1">
                            <span className="text-center">{display(row.frequency)}</span>
                            <div className="text-center">
                              <input aria-label={`${student.studentName} — ${row.subjectName} — exame`} value={current} disabled={pending || !editable} onChange={(event) => setDrafts((state) => ({ ...state, [key]: event.target.value }))} inputMode="decimal" className="h-7 w-12 border border-black/30 bg-white text-center text-[10px] outline-none focus:ring-1 focus:ring-black disabled:bg-black/5" />
                              {draft !== undefined ? <Button size="sm" variant="ghost" className="h-6 px-1 text-[9px]" onClick={() => save(row)} disabled={pending}>Guardar</Button> : null}
                              {row.examResultStatus === "PUBLISHED" ? <input aria-label={`Motivo da correção — ${student.studentName} — ${row.subjectName}`} value={reasons[key] ?? ""} onChange={(event) => setReasons((state) => ({ ...state, [key]: event.target.value }))} placeholder="Motivo" className="mt-1 h-6 w-full border border-black/20 px-1 text-[9px] print:hidden" /> : null}
                            </div>
                            <span className="text-center font-semibold">{display(row.finalValue)}</span>
                          </div>
                        </td>
                      );
                    })}
                    <td className="border px-2 py-1 text-center font-semibold">{display(global)}</td>
                    <td className="border px-2 py-1 text-center font-semibold">{global != null && !hasFailed ? "X" : ""}</td>
                    <td className="border px-2 py-1 text-center font-semibold">{global != null && hasFailed ? "X" : ""}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="grid grid-cols-2 gap-6 border-t p-4 text-[10px]">
          <div><div className="font-semibold">Legenda</div><p>c) Concluiu · d) Não faz a disciplina · Exc Excluído · A Ausente · F Fraude.</p></div>
          <div className="text-right"><div>O Presidente do Conselho de Exame</div><div className="mt-8 border-t border-black/50 pt-1">Assinatura</div></div>
        </div>
      </section>

      <section className="official-pauta border bg-white p-4 text-black print:break-before-page">
        <h2 className="mb-3 text-center text-xs font-bold uppercase">Mapa de Aproveitamento Pedagógico</h2>
        <div className="overflow-x-auto">
          <table className="min-w-[1500px] w-full border-collapse text-[9px]">
            <thead>
              <tr>
                <th rowSpan={2} className="border px-1 py-1 text-left">Escala de Notas</th>
                <th rowSpan={2} className="border px-1 py-1">Gen.</th>
                {subjectStats.map((subject) => <th key={subject.code} colSpan={3} className="border px-1 py-1 text-center">{subject.name}</th>)}
              </tr>
              <tr>
                {subjectStats.flatMap((subject) => [1, 2, "T"].map((call) => <th key={`${subject.code}-${call}`} className="border px-1 py-1">{call === "T" ? "Total" : `${call}ª Ch`}</th>))}
              </tr>
            </thead>
            <tbody>
              {PAUTA_BANDS.map((band, bandIndex) =>
                (["M", "H", "HM"] as const).map((gender) => (
                  <tr key={`${band.label}-${gender}`}>
                    {gender === "M" ? <td rowSpan={3} className="border px-1 py-1">{band.label}</td> : null}
                    <td className="border px-1 py-1 text-center">{gender}</td>
                    {subjectStats.flatMap((subject) => {
                      const a = subject.calls[1][gender].bands[bandIndex];
                      const b = subject.calls[2][gender].bands[bandIndex];
                      return [a[gender === "HM" ? "HM" : gender], b[gender === "HM" ? "HM" : gender], (a[gender === "HM" ? "HM" : gender] + b[gender === "HM" ? "HM" : gender])].map((value, index) => <td key={index} className="border px-1 py-1 text-center">{value}</td>);
                    })}
                  </tr>
                )),
              )}
              {(["Previstos", "Avaliados", "Positivos", "% dos Positivos"] as const).flatMap((metric) =>
                (["M", "H", "HM"] as const).map((gender, index) => (
                  <tr key={`${metric}-${gender}`}>
                    {index === 0 ? <td rowSpan={3} colSpan={1} className="border px-1 py-1 font-semibold">{metric}</td> : null}
                    <td className="border px-1 py-1 text-center">{gender}</td>
                    {subjectStats.flatMap((subject) => {
                      const value = (call: 1 | 2) => {
                        const s = subject.calls[call][gender];
                        if (metric === "Previstos") return s.previstos;
                        if (metric === "Avaliados") return s.avaliados;
                        if (metric === "Positivos") return s.positivos;
                        return s.percentPositive;
                      };
                      const a = value(1);
                      const b = value(2);
                      const total = metric === "% dos Positivos" ? null : Number(a) + Number(b);
                      return [a, b, total].map((v, i) => <td key={i} className="border px-1 py-1 text-center">{metric === "% dos Positivos" ? percent(v as number | null) : v ?? "—"}</td>);
                    })}
                  </tr>
                )),
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-5 grid gap-4 md:grid-cols-4">
          {(["M", "H", "HM"] as const).map((gender) => (
            <div key={gender} className="border p-3 text-[10px]">
              <div className="font-semibold">{gender}</div>
              <div>Examinados: {overallStats.byGender[gender].examined}</div>
              <div>Positivos: {overallStats.byGender[gender].positive}</div>
              <div>% Positivos: {percent(overallStats.byGender[gender].percentPositive)}</div>
            </div>
          ))}
          <div className="border p-3 text-[10px]">
            <div className="font-semibold">HM</div>
            <div>Examinados: {overallStats.examined}</div>
            <div>Positivos: {overallStats.positives}</div>
            <div>% Positivos: {percent(overallStats.percentPositive)}</div>
          </div>
        </div>
      </section>

      <style jsx global>{`
        @media print {
          @page { size: A3 landscape; margin: 8mm; }
          body { background: white !important; }
          .official-pauta { break-inside: avoid; box-shadow: none !important; }
          .official-pauta input { border: 0 !important; background: transparent !important; }
          .official-pauta button, .official-pauta input[placeholder="Motivo"] { display: none !important; }
        }
      `}
      </style>
    </div>
  );
}
