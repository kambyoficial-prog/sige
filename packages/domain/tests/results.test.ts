import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  calculateFinal,
  calculateFrequency,
  calculateTrimester,
  classifyMozambiqueSecondary2022,
  roundMozambiqueOfficialScore,
} from "../src/results.js";

describe("Mozambique secondary assessment rules 2022", () => {
  it("calculates MACS and MT from the entered ACS and AT", () => {
    const result = calculateTrimester({
      acs: [
        { score: 12, status: "ENTERED" },
        { score: 18, status: "ENTERED" },
        { score: 16, status: "ENTERED" },
      ],
      at: { score: 15, status: "ENTERED" },
    });

    assert.ok(Math.abs((result.macs ?? 0) - (15.3333333333)) < 1e-9);
    assert.ok(Math.abs((result.mt ?? 0) - ((2 * (46 / 3) + 15) / 3)) < 1e-9);
    assert.equal(result.complete, true);
  });

  it("supports more than the minimum number of ACS without fixed columns", () => {
    const result = calculateTrimester({
      acs: [
        { score: 10, status: "ENTERED" },
        { score: 12, status: "ENTERED" },
        { score: 14, status: "ENTERED" },
        { score: 16, status: "ENTERED" },
      ],
      at: { score: 18, status: "ENTERED" },
    });

    assert.equal(result.macs, 13);
    assert.ok(Math.abs((result.mt ?? 0) - (44 / 3)) < 1e-9);
  });

  it("does not publish a trimester result when the regulatory minimum is incomplete", () => {
    const result = calculateTrimester({
      acs: [{ score: 15, status: "ENTERED" }],
      at: { score: 15, status: "ENTERED" },
    });

    assert.equal(result.complete, false);
    assert.equal(result.mt, null);
  });

  it("calculates MFD only when all three trimesters are complete", () => {
    const result = calculateFrequency([
      {
        acs: [
          { score: 10, status: "ENTERED" },
          { score: 14, status: "ENTERED" },
        ],
        at: { score: 12, status: "ENTERED" },
      },
      {
        acs: [
          { score: 12, status: "ENTERED" },
          { score: 16, status: "ENTERED" },
        ],
        at: { score: 14, status: "ENTERED" },
      },
      {
        acs: [
          { score: 14, status: "ENTERED" },
          { score: 18, status: "ENTERED" },
        ],
        at: { score: 16, status: "ENTERED" },
      },
    ]);

    assert.equal(result.complete, true);
    assert.ok(Math.abs((result.mfd ?? 0) - (14)) < 1e-9);
  });

  it("calculates final grade with the examination weight required by 2022 rules", () => {
    const result = calculateFinal(15, 12);
    assert.ok(Math.abs(result.nf - (14)) < 1e-9);
  });

  it("rounds official presentation to whole values", () => {
    assert.equal(roundMozambiqueOfficialScore(9.5), 10);
    assert.equal(roundMozambiqueOfficialScore(9.4), 9);
  });

  it("uses the official qualitative bands", () => {
    assert.equal(classifyMozambiqueSecondary2022(19), "EXCELENTE");
    assert.equal(classifyMozambiqueSecondary2022(17), "MUITO_BOM");
    assert.equal(classifyMozambiqueSecondary2022(14), "BOM");
    assert.equal(classifyMozambiqueSecondary2022(10), "SUFICIENTE");
    assert.equal(classifyMozambiqueSecondary2022(9), "NAO_SUFICIENTE");
  });
});
