import { mean, roundForPresentation } from "./assessment.js";

export const MOZAMBIQUE_SECONDARY_2022_RULE_VERSION =
  "MZ-ES-2022-06-30";

export interface ContinuousAssessment {
  score: number | null;
  status: "ENTERED" | "ABSENT" | "EXCUSED" | "MISSING";
}

export interface TrimesterInput {
  acs: readonly ContinuousAssessment[];
  at: ContinuousAssessment | null;
}

export interface TrimesterResult {
  macs: number | null;
  mt: number | null;
  complete: boolean;
  acsCount: number;
  missingAcs: number;
  atPresent: boolean;
}

export interface FrequencyResult {
  mfd: number | null;
  complete: boolean;
  trimesters: readonly TrimesterResult[];
}

export interface FinalResult {
  nd: number;
  exam: number;
  nf: number;
}

function enteredScores(
  values: readonly ContinuousAssessment[],
): number[] {
  return values
    .filter((value) => value.status === "ENTERED" && value.score !== null)
    .map((value) => value.score as number);
}

/**
 * Mozambique Ensino Secundário — Regulamento de Avaliação (2022):
 * MACS = arithmetic mean of ACS results.
 * MT   = (2 * MACS + AT) / 3.
 *
 * The system may store more than the regulatory minimum. Only entered
 * assessments participate in MACS; publication is blocked unless the
 * minimum required set is complete.
 */
export function calculateTrimester(
  input: TrimesterInput,
): TrimesterResult {
  const scores = enteredScores(input.acs);
  const macs = mean(scores);

  const atPresent =
    input.at?.status === "ENTERED" && input.at.score !== null;

  const complete = scores.length >= 2 && atPresent;

  return {
    macs,
    mt:
      complete && macs !== null
        ? (2 * macs + (input.at?.score as number)) / 3
        : null,
    complete,
    acsCount: input.acs.length,
    missingAcs: Math.max(0, 2 - scores.length),
    atPresent,
  };
}

export function calculateFrequency(
  trimesters: readonly TrimesterInput[],
): FrequencyResult {
  const calculated = trimesters.map(calculateTrimester);
  const values = calculated
    .map((item) => item.mt)
    .filter((value): value is number => value !== null);

  return {
    mfd: values.length === 3 ? mean(values) : null,
    complete: calculated.length === 3 && calculated.every((item) => item.complete),
    trimesters: calculated,
  };
}

/**
 * For schools covered by the 2022 regulation with pedagogical parallelism:
 * NF = (2 * ND + NE) / 3.
 */
export function calculateFinal(
  nd: number,
  exam: number,
): FinalResult {
  if (!Number.isFinite(nd) || nd < 0 || nd > 20) {
    throw new RangeError("nd must be between 0 and 20.");
  }

  if (!Number.isFinite(exam) || exam < 0 || exam > 20) {
    throw new RangeError("exam must be between 0 and 20.");
  }

  return {
    nd,
    exam,
    nf: (2 * nd + exam) / 3,
  };
}

export function classifyMozambiqueSecondary2022(
  score: number,
): "EXCELENTE" | "MUITO_BOM" | "BOM" | "SUFICIENTE" | "NAO_SUFICIENTE" {
  const rounded = Math.round(score);

  if (rounded >= 19) return "EXCELENTE";
  if (rounded >= 17) return "MUITO_BOM";
  if (rounded >= 14) return "BOM";
  if (rounded >= 10) return "SUFICIENTE";
  return "NAO_SUFICIENTE";
}

export function roundMozambiqueOfficialScore(score: number): number {
  return roundForPresentation(score, 0);
}
