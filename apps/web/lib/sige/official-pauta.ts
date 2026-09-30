export type OfficialPautaGroup = "A" | "B";

export type OfficialPautaSubject = {
  code: string;
  name: string;
  span: 1 | 3;
};

export const OFFICIAL_PAUTA_SUBJECTS: Record<OfficialPautaGroup, OfficialPautaSubject[]> = {
  A: [
    { code: "POR", name: "Português", span: 3 },
    { code: "ING", name: "Inglês", span: 3 },
    { code: "FIL", name: "Filosofia", span: 3 },
    { code: "MAT", name: "Matemática", span: 3 },
    { code: "FRA", name: "Francês", span: 3 },
    { code: "HIS", name: "História", span: 3 },
    { code: "GEO", name: "Geografia", span: 3 },
    { code: "TIC", name: "TICs", span: 1 },
    { code: "NE", name: "N.E", span: 1 },
    { code: "EF", name: "Ed. Física", span: 1 },
    { code: "COMP", name: "COMP", span: 1 },
  ],
  B: [
    { code: "POR", name: "Português", span: 3 },
    { code: "ING", name: "Inglês", span: 3 },
    { code: "FIL", name: "Filosofia", span: 3 },
    { code: "MAT", name: "Matemática", span: 3 },
    { code: "BIO", name: "Biologia", span: 3 },
    { code: "QUI", name: "Química", span: 3 },
    { code: "FIS", name: "Física", span: 3 },
    { code: "TIC", name: "TICs", span: 1 },
    { code: "AGP", name: "AGP", span: 1 },
    { code: "EF", name: "Ed. Física", span: 1 },
    { code: "COMP", name: "COMP", span: 1 },
  ],
};

export function normalizePautaGroup(pathwayName: string | null | undefined): OfficialPautaGroup | null {
  const match = pathwayName?.match(/Grupo\s+([AB])/i);
  return match ? (match[1].toUpperCase() as OfficialPautaGroup) : null;
}

export function classifyExamCall(title: string | null | undefined): 1 | 2 {
  const value = (title ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return /2\s*(a|ª|o)?\s*(chamada|ch\.?|fase)/.test(value) ? 2 : 1;
}

export type PautaStudentStat = {
  studentId: string;
  gender: "M" | "H" | null;
};

export type PautaExamStatRow = {
  studentId: string;
  subjectCode: string;
  frequency: number | null;
  examCall: 1 | 2;
  examScore: number | null;
};

export type PautaBand = {
  label: string;
  min: number;
  max: number;
};

export const PAUTA_BANDS: PautaBand[] = [
  { label: "0 - 5.9", min: 0, max: 5.9 },
  { label: "6 - 8.9", min: 6, max: 8.9 },
  { label: "9 - 13.9", min: 9, max: 13.9 },
  { label: "14 - 16.9", min: 14, max: 16.9 },
  { label: "17 - 20", min: 17, max: 20 },
];

export type PautaCallStats = {
  previstos: number;
  avaliados: number;
  positivos: number;
  percentPositive: number | null;
  bands: Array<{ M: number; H: number; HM: number }>;
};

export type PautaSubjectStats = {
  code: string;
  name: string;
  calls: Record<1 | 2, Record<"M" | "H" | "HM", PautaCallStats>>;
};

function inRange(value: number | null, band: PautaBand) {
  return value != null && value >= band.min && value <= band.max;
}

export function buildPautaSubjectStats(
  students: PautaStudentStat[],
  rows: PautaExamStatRow[],
  subjects: OfficialPautaSubject[],
): PautaSubjectStats[] {
  const studentMap = new Map(students.map((student) => [student.studentId, student]));
  const normalized = rows.filter((row) => studentMap.has(row.studentId));

  return subjects
    .filter((subject) => subject.span === 3)
    .map((subject) => {
      const calls = { 1: {} as Record<"M" | "H" | "HM", PautaCallStats>, 2: {} as Record<"M" | "H" | "HM", PautaCallStats> };

      for (const call of [1, 2] as const) {
        for (const gender of ["M", "H", "HM"] as const) {
          const genderStudents = students.filter((student) => gender === "HM" || student.gender === gender);
          const genderIds = new Set(genderStudents.map((student) => student.studentId));
          const subjectRows = normalized.filter(
            (row) => row.subjectCode === subject.code && row.examCall === call && genderIds.has(row.studentId),
          );
          const previstos = new Set(
            normalized
              .filter((row) => row.subjectCode === subject.code && row.frequency != null && genderIds.has(row.studentId))
              .map((row) => row.studentId),
          ).size;
          const evaluatedRows = subjectRows.filter((row) => row.examScore != null);
          const avaliados = new Set(evaluatedRows.map((row) => row.studentId)).size;
          const positivos = new Set(evaluatedRows.filter((row) => row.examScore! >= 10).map((row) => row.studentId)).size;

          calls[call][gender] = {
            previstos,
            avaliados,
            positivos,
            percentPositive: avaliados ? (positivos / avaliados) * 100 : null,
            bands: PAUTA_BANDS.map((band) => {
              const ids = new Set(
                evaluatedRows.filter((row) => inRange(row.examScore, band)).map((row) => row.studentId),
              );
              const M = new Set([...ids].filter((id) => studentMap.get(id)?.gender === "M")).size;
              const H = new Set([...ids].filter((id) => studentMap.get(id)?.gender === "H")).size;
              return { M, H, HM: M + H };
            }),
          };
        }
      }

      return { code: subject.code, name: subject.name, calls };
    });
}

export function buildOverallPautaStats(
  students: PautaStudentStat[],
  rows: PautaExamStatRow[],
) {
  const byStudent = new Map<string, { first: number | null; second: number | null }>();
  for (const row of rows) {
    const current = byStudent.get(row.studentId) ?? { first: null, second: null };
    if (row.examScore != null) current[row.examCall === 1 ? "first" : "second"] = row.examScore;
    byStudent.set(row.studentId, current);
  }

  const evaluated = students.filter((student) => {
    const item = byStudent.get(student.studentId);
    return item?.first != null || item?.second != null;
  });
  const examined = evaluated.length;
  const positives = evaluated.filter((student) => {
    const item = byStudent.get(student.studentId)!;
    return (item.first ?? item.second)! >= 10 || (item.second ?? item.first)! >= 10;
  }).length;

  const byGender = (gender: "M" | "H" | "HM") => {
    const scoped = evaluated.filter((student) => gender === "HM" || student.gender === gender);
    const positive = scoped.filter((student) => {
      const item = byStudent.get(student.studentId)!;
      return (item.first ?? item.second)! >= 10 || (item.second ?? item.first)! >= 10;
    }).length;
    return { examined: scoped.length, positive, percentPositive: scoped.length ? (positive / scoped.length) * 100 : null };
  };

  return { examined, positives, percentPositive: examined ? (positives / examined) * 100 : null, byGender: { M: byGender("M"), H: byGender("H"), HM: byGender("HM") } };
}
