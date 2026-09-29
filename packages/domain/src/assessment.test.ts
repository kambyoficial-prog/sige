import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeScore,
  roundForPresentation,
  weightedMean,
} from "./assessment.js";

test("normalizes arbitrary assessment scales to the school 0-20 domain scale", () => {
  assert.equal(normalizeScore(15, 20), 15);
  assert.equal(normalizeScore(25, 50), 10);
});

test("weighted mean ignores no value accidentally and remains deterministic", () => {
  assert.equal(
    weightedMean([
      { score: 10, maxScore: 20, weight: 1 },
      { score: 20, maxScore: 20, weight: 2 },
    ]),
    16.666666666666668,
  );
});

test("zero total weight falls back to arithmetic mean", () => {
  assert.equal(
    weightedMean([
      { score: 10, maxScore: 20, weight: 0 },
      { score: 14, maxScore: 20, weight: 0 },
    ]),
    12,
  );
});

test("presentation rounding is explicit and happens after calculation", () => {
  assert.equal(roundForPresentation(16.666666666666668, 2), 16.67);
});

test("invalid score and invalid scale are rejected", () => {
  assert.throws(() => normalizeScore(21, 20), RangeError);
  assert.throws(() => normalizeScore(1, 0), RangeError);
});
