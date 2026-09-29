import { assertScoreInScale, mean } from "./index.js";

export interface NumericAssessmentInput {
  score: number;
  maxScore: number;
  weight?: number | null;
}

export function normalizeScore(score: number, maxScore: number): number {
  if (!Number.isFinite(maxScore) || maxScore <= 0) {
    throw new RangeError("maxScore must be greater than zero.");
  }
  if (!Number.isFinite(score) || score < 0 || score > maxScore) {
    throw new RangeError(`Score must be between 0 and ${maxScore}.`);
  }

  return (score / maxScore) * 20;
}

export function weightedMean(values: readonly NumericAssessmentInput[]): number | null {
  if (values.length === 0) return null;

  let weightedTotal = 0;
  let totalWeight = 0;

  for (const value of values) {
    assertScoreInScale(value.score, value.maxScore);
    const weight = value.weight ?? 1;

    if (!Number.isFinite(weight) || weight < 0) {
      throw new RangeError("Assessment weight must be non-negative.");
    }

    weightedTotal += normalizeScore(value.score, value.maxScore) * weight;
    totalWeight += weight;
  }

  return totalWeight === 0 ? mean(values.map((value) => normalizeScore(value.score, value.maxScore))) : weightedTotal / totalWeight;
}

export function roundForPresentation(value: number, decimals = 2): number {
  if (!Number.isFinite(value) || decimals < 0 || !Number.isInteger(decimals)) {
    throw new RangeError("Invalid rounding arguments.");
  }

  const factor = 10 ** decimals;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}
