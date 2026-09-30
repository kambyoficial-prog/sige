"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";
import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

const registerStudentSchema = z.object({
  schoolId: z.string().uuid(),
  firstName: z.string().trim().min(2).max(120),
  lastName: z.string().trim().max(120).optional(),
  gender: z.enum(["M", "F"]).optional(),
  birthDate: z.string().optional(),
  documentType: z.string().trim().max(40).optional(),
  documentValue: z.string().trim().max(120).optional(),
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

export type AdmissionDuplicateMatch = {
  id: string;
  schoolNumber: string;
  fullName: string;
  birthDate: string | null;
  status: string;
  enrollmentStatus: string | null;
  className: string | null;
  matchReasons: Array<"DOCUMENT" | "NAME_BIRTH_DATE">;
};

function normalizeLookup(value: string | undefined) {
  return value?.trim() || "";
}

export async function findAdmissionDuplicateMatches(input: {
  schoolId: string;
  firstName: string;
  lastName?: string;
  birthDate?: string;
  documentType?: string;
  documentValue?: string;
}): Promise<{ ok: true; matches: AdmissionDuplicateMatch[] } | { ok: false; code: string }> {
  const firstName = normalizeLookup(input.firstName);
  const lastName = normalizeLookup(input.lastName);
  const birthDate = normalizeLookup(input.birthDate);
  const documentType = normalizeLookup(input.documentType);
  const documentValue = normalizeLookup(input.documentValue);

  if (!z.string().uuid().safeParse(input.schoolId).success || firstName.length < 2) {
    return { ok: false, code: "INVALID_ARGUMENT" };
  }

  try {
    const { supabase } = await requireAuthenticatedServerClient();
    const matches = new Map<string, AdmissionDuplicateMatch>();

    if (documentType && documentValue) {
      let documentQuery = supabase
        .from("student_identifiers")
        .select("student_id,type,value")
        .eq("value", documentValue);

      if (documentType) documentQuery = documentQuery.eq("type", documentType);

      const { data: identifiers, error: identifierError } = await documentQuery;
      if (identifierError) throw identifierError;

      for (const identifier of identifiers ?? []) {
        const { data: student, error } = await supabase
          .from("student_directory")
          .select("id,school_id,school_number,full_name,birth_date,status,enrollment_status,class_name")
          .eq("id", identifier.student_id)
          .eq("school_id", input.schoolId)
          .maybeSingle();

        if (student) {
          matches.set(student.id, {
            id: student.id,
            schoolNumber: student.school_number,
            fullName: student.full_name,
            birthDate: student.birth_date,
            status: student.status,
            enrollmentStatus: student.enrollment_status,
            className: student.class_name,
            matchReasons: ["DOCUMENT"],
          });

      }
      }
    }

    if (birthDate) {
      const fullName = [firstName, lastName].filter(Boolean).join(" ");
      const { data: students, error: nameError } = await supabase
        .from("student_directory")
        .select("id,school_id,school_number,full_name,birth_date,status,enrollment_status,class_name")
        .eq("school_id", input.schoolId)
        .eq("birth_date", birthDate)
        .ilike("full_name", fullName);

      if (nameError) throw nameError;

      for (const student of students ?? []) {
        const existing = matches.get(student.id);
        matches.set(student.id, {
          id: student.id,
          schoolNumber: student.school_number,
          fullName: student.full_name,
          birthDate: student.birth_date,
          status: student.status,
          enrollmentStatus: student.enrollment_status,
          className: student.class_name,
          matchReasons: existing
            ? Array.from(new Set([...existing.matchReasons, "NAME_BIRTH_DATE"]))
            : ["NAME_BIRTH_DATE"],
        });
      }
    }

    return { ok: true, matches: [...matches.values()] };
  } catch (error) {
    return failure(error) as { ok: false; code: string };
  }
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
