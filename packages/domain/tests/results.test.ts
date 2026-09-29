import { describe, expect, it } from "vitest";
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

    expect(result.macs).toBeCloseTo(15.3333333333);
    expect(result.mt).toBeCloseTo((2 * (46 / 3) + 15) / 3);
    expect(result.complete).toBe(true);
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

    expect(result.macs).toBe(13);
    expect(result.mt).toBeCloseTo(44 / 3);
  });

  it("does not publish a trimester result when the regulatory minimum is incomplete", () => {
    const result = calculateTrimester({
      acs: [{ score: 15, status: "ENTERED" }],
      at: { score: 15, status: "ENTERED" },
    });

    expect(result.complete).toBe(false);
    expect(result.mt).toBeNull();
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

    expect(result.complete).toBe(true);
    expect(result.mfd).toBeCloseTo(14);
  });

  it("calculates final grade with the examination weight required by 2022 rules", () => {
    const result = calculateFinal(15, 12);
    expect(result.nf).toBeCloseTo(14);
  });

  it("rounds official presentation to whole values", () => {
    expect(roundMozambiqueOfficialScore(9.5)).toBe(10);
    expect(roundMozambiqueOfficialScore(9.4)).toBe(9);
  });

  it("uses the official qualitative bands", () => {
    expect(classifyMozambiqueSecondary2022(19)).toBe("EXCELENTE");
    expect(classifyMozambiqueSecondary2022(17)).toBe("MUITO_BOM");
    expect(classifyMozambiqueSecondary2022(14)).toBe("BOM");
    expect(classifyMozambiqueSecondary2022(10)).toBe("SUFICIENTE");
    expect(classifyMozambiqueSecondary2022(9)).toBe("NAO_SUFICIENTE");
  });
});
