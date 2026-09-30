"use server";

import { z } from "zod";
import { executeCommand } from "@/lib/sige/commands";
import { normalizeSigeError } from "@sige/contracts";

const paymentSchema = z.object({
  studentId: z.string().uuid(),
  amount: z.coerce.number().positive(),
  method: z.enum(["CASH","BANK_TRANSFER","MOBILE_MONEY","CARD","OTHER"]),
  paidAt: z.string().datetime().optional(),
  externalReference: z.string().max(200).optional(),
  notes: z.string().max(1000).optional(),
});

const confirmSchema = z.object({ paymentId: z.string().uuid() });
const allocationSchema = z.object({ paymentId: z.string().uuid(), chargeId: z.string().uuid(), amount: z.coerce.number().positive() });
const reversalSchema = z.object({ paymentId: z.string().uuid(), reason: z.string().min(3).max(1000) });
const receiptSchema = z.object({ paymentId: z.string().uuid(), receiptNumber: z.string().max(100).default("AUTO") });

export async function recordPaymentAction(input: unknown) {
  try { const value=paymentSchema.parse(input); return await executeCommand("record_payment",{...value,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function confirmPaymentAction(input: unknown) {
  try { const value=confirmSchema.parse(input); return await executeCommand("confirm_payment",{...value,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function allocatePaymentAction(input: unknown) {
  try { const value=allocationSchema.parse(input); return await executeCommand("allocate_payment",{...value,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function reversePaymentAction(input: unknown) {
  try { const value=reversalSchema.parse(input); return await executeCommand("reverse_payment",{...value,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
export async function issueReceiptAction(input: unknown) {
  try { const value=receiptSchema.parse(input); return await executeCommand("issue_receipt",{...value,idempotencyKey:crypto.randomUUID()}); }
  catch(error){ throw normalizeSigeError(error); }
}
