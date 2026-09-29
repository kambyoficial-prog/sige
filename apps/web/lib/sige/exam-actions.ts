"use server";

import { z } from "zod";
import { executeCommand } from "@/lib/sige/commands";
import { normalizeSigeError } from "@sige/contracts";

const sessionSchema = z.object({
  academicYearId: z.string().uuid(),
  gradeLevelId: z.string().uuid(),
  epoch: z.coerce.number().int().min(1).max(2).transform((value) => value as 1 | 2),
  startsOn: z.string(),
  endsOn: z.string(),
});

const registrationSchema = z.object({
  examSessionId: z.string().uuid(),
  studentId: z.string().uuid(),
  courseOfferingId: z.string().uuid(),
  eligibilityStatus: z.enum(["PENDING","ELIGIBLE","INELIGIBLE","AUTHORIZED_ABSENCE","FRAUD_BLOCKED"]),
  reason: z.string().max(1000).nullable(),
});

const statusSchema = z.object({
  examSessionId: z.string().uuid(),
  status: z.enum(["OPEN","CLOSED","CANCELLED"]),
});

export async function createExamSessionAction(input: unknown) {
  try {
    const value = sessionSchema.parse(input);
    return await executeCommand("create_exam_session", {
      ...value,
      idempotencyKey: crypto.randomUUID(),
    });
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function setExamSessionStatusAction(input: unknown) {
  try {
    const value = statusSchema.parse(input);
    return await executeCommand("set_exam_session_status", {
      ...value,
      idempotencyKey: crypto.randomUUID(),
    });
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function registerExamCandidateAction(input: unknown) {
  try {
    const value = registrationSchema.parse(input);
    return await executeCommand("register_exam_candidate", {
      ...value,
      idempotencyKey: crypto.randomUUID(),
    });
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
