"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";

const enrollmentSchema = z.object({
  studentId: z.string().uuid(),
  academicYearId: z.string().uuid(),
  gradeLevelId: z.string().uuid(),
  pathwayId: z.preprocess((value)=>value===""?undefined:value,z.string().uuid().optional()),
  entryType: z.enum(["INITIAL","TRANSFER_IN","REENTRY"]),
  enrolledOn: z.string().min(10),
});

const placementSchema = z.object({
  enrollmentId: z.string().uuid(),
  classGroupId: z.string().uuid(),
  startsOn: z.string().min(10),
  reason: z.string().trim().max(240).optional(),
});

type Result = { ok: true; result: unknown } | { ok: false; code: string };

function failure(error: unknown): Result {
  return { ok: false, code: error instanceof SigeApplicationError ? error.code : "UNKNOWN" };
}

export async function enrollStudentAction(input: unknown): Promise<Result> {
  const parsed = enrollmentSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return { ok: true, result: await executeCommand("enroll_student", { ...parsed.data, idempotencyKey: crypto.randomUUID() }) };
  } catch (error) {
    return failure(error);
  }
}

export async function placeStudentAction(input: unknown): Promise<Result> {
  const parsed = placementSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return { ok: true, result: await executeCommand("place_student_in_class", { ...parsed.data, idempotencyKey: crypto.randomUUID() }) };
  } catch (error) {
    return failure(error);
  }
}
