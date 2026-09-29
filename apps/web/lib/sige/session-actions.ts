"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";

const openSchema = z.object({
  scheduleEntryId: z.string().uuid(),
  sessionDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  topic: z.string().trim().max(240).optional(),
  notes: z.string().trim().max(1000).optional(),
});
const closeSchema = z.object({
  classSessionId: z.string().uuid(),
  reason: z.string().trim().max(500).optional(),
});
const attendanceSchema = z.object({
  classSessionId: z.string().uuid(),
  studentId: z.string().uuid(),
  status: z.enum(["PRESENT", "ABSENT", "EXCUSED", "LATE"]),
  minutesLate: z.preprocess(
    (value) => value === "" || value === undefined ? undefined : value,
    z.coerce.number().int().min(1).max(600).optional(),
  ),
  reason: z.string().trim().max(500).optional(),
});

type Result = { ok: true; result: unknown } | { ok: false; code: string };

function failure(error: unknown): Result {
  return {
    ok: false,
    code: error instanceof SigeApplicationError ? error.code : "UNKNOWN",
  };
}

export async function openClassSessionAction(input: unknown): Promise<Result> {
  const parsed = openSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return {
      ok: true,
      result: await executeCommand("open_class_session", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return failure(error);
  }
}

export async function closeClassSessionAction(input: unknown): Promise<Result> {
  const parsed = closeSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return {
      ok: true,
      result: await executeCommand("close_class_session", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return failure(error);
  }
}

export async function recordSessionAttendanceAction(input: unknown): Promise<Result> {
  const parsed = attendanceSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return {
      ok: true,
      result: await executeCommand("record_session_attendance", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return failure(error);
  }
}
