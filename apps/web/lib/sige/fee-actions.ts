"use server";

import { z } from "zod";
import { executeCommand } from "@/lib/sige/commands";
import { normalizeSigeError } from "@sige/contracts";

const feeTypeSchema = z.object({ schoolId:z.string().uuid(), code:z.string().trim().min(2).max(40), name:z.string().trim().min(2).max(120) });
const feePlanSchema = z.object({ schoolId:z.string().uuid(), academicYearId:z.string().uuid(), code:z.string().trim().min(2).max(40), name:z.string().trim().min(2).max(120) });
const itemSchema = z.object({ feePlanId:z.string().uuid(), feeTypeId:z.string().uuid(), amount:z.coerce.number().positive(), dueDay:z.coerce.number().int().min(1).max(31).optional(), sequenceNo:z.coerce.number().int().positive().optional() });

export async function createFeeTypeAction(input: unknown) {
  try { const v=feeTypeSchema.parse(input); return await executeCommand("create_fee_type",{...v,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function createFeePlanAction(input: unknown) {
  try { const v=feePlanSchema.parse(input); return await executeCommand("create_fee_plan",{...v,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function addFeePlanItemAction(input: unknown) {
  try { const v=itemSchema.parse(input); return await executeCommand("add_fee_plan_item",{...v,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
