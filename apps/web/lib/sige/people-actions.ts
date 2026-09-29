"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";

const registerStudentSchema = z.object({
  schoolId: z.string().uuid(),
  schoolNumber: z.string().trim().min(1).max(40),
  fullName: z.string().trim().min(2).max(160),
  firstName: z.string().trim().max(80).optional(),
  lastName: z.string().trim().max(80).optional(),
  gender: z.string().trim().max(40).optional(),
  birthDate: z.string().optional(),
  nationalId: z.string().trim().max(80).optional(),
  phone: z.string().trim().max(40).optional(),
  email: z.string().trim().email().max(160).optional().or(z.literal("")),
  address: z.string().trim().max(240).optional(),
  admissionDate: z.string().optional(),
});

const guardianSchema = z.object({
  schoolId: z.string().uuid(),
  studentId: z.string().uuid(),
  fullName: z.string().trim().min(2).max(160),
  relationship: z.string().trim().max(80).optional(),
  occupation: z.string().trim().max(120).optional(),
  identityNumber: z.string().trim().max(80).optional(),
  address: z.string().trim().max(240).optional(),
  phone: z.string().trim().max(40).optional(),
  gender: z.string().trim().max(40).optional(),
  birthDate: z.string().optional(),
  nationalId: z.string().trim().max(80).optional(),
  isPrimary: z.boolean().optional(),
  livesWithStudent: z.boolean().optional(),
});

type ActionResult =
  | { ok: true; result: unknown }
  | { ok: false; code: string };

function failure(error: unknown): ActionResult {
  return {
    ok: false,
    code: error instanceof SigeApplicationError ? error.code : "UNKNOWN",
  };
}

export async function registerStudentAction(input: unknown): Promise<ActionResult> {
  const parsed = registerStudentSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };

  try {
    return {
      ok: true,
      result: await executeCommand("register_student", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return failure(error);
  }
}

export async function createGuardianAction(input: unknown): Promise<ActionResult> {
  const parsed = guardianSchema.safeParse(input);
  if (!parsed.success) return { ok: false, code: "INVALID_ARGUMENT" };

  try {
    return {
      ok: true,
      result: await executeCommand("create_guardian", {
        ...parsed.data,
        idempotencyKey: crypto.randomUUID(),
      }),
    };
  } catch (error) {
    return failure(error);
  }
}
