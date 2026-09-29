"use server";

import { z } from "zod";
import { executeCommand } from "@/lib/sige/commands";
import { normalizeSigeError } from "@sige/contracts";

const saveSchema = z.object({
  assessmentId: z.string().uuid(),
  studentId: z.string().uuid(),
  rawScore: z.number().min(0).nullable(),
  status: z.enum(["ENTERED","ABSENT","EXCUSED","INVALIDATED"]),
  comment: z.string().max(1000).nullable().optional(),
});

export async function saveAssessmentResultAction(input: unknown) {
  try {
    const value = saveSchema.parse(input);
    return await executeCommand("save_assessment_result", {
      ...value,
      comment: value.comment ?? undefined,
      idempotencyKey: crypto.randomUUID(),
    });
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
