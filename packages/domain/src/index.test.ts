import test from "node:test";
import assert from "node:assert/strict";
import { assertScoreInScale, mean } from "./index.js";

test("mean returns null for an empty set", () => {
  assert.equal(mean([]), null);
});

test("mean does not round early", () => {
  assert.equal(mean([10, 11]), 10.5);
});

test("score validation enforces the configured scale", () => {
  assert.doesNotThrow(() => assertScoreInScale(0));
  assert.doesNotThrow(() => assertScoreInScale(20));
  assert.throws(() => assertScoreInScale(-1), RangeError);
  assert.throws(() => assertScoreInScale(21), RangeError);
});
