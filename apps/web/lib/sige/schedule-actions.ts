"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";

const createSchema = z.object({
  academicYearId: z.string().uuid(),
  classGroupId: z.string().uuid(),
  courseOfferingId: z.string().uuid(),
  teacherAssignmentId: z.string().uuid(),
  teacherId: z.string().uuid(),
  roomId: z.string().uuid().optional(),
  periodId: z.string().uuid(),
  dayOfWeek: z.coerce.number().int().min(1).max(7),
  validFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  validUntil: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  notes: z.string().trim().max(500).optional(),
});

type Result = { ok: true; result: unknown } | { ok: false; code: string };

export async function createScheduleEntryAction(input: unknown): Promise<Result> {
  const parsed = createSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };
  try {
    return {
      ok: true,
      result: await executeCommand("create_schedule_entry", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return {
      ok: false,
      code: error instanceof SigeApplicationError ? error.code : "UNKNOWN",
    };
  }
}
