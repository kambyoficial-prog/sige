"use server";

import crypto from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { getCurrentAccessContext } from "@/lib/sige/access";

const schema = z.object({
  schoolId: z.string().uuid(),
  studentId: z.string().uuid(),
});

function generateTemporaryPassword() {
  return crypto.randomBytes(18).toString("base64url");
}

function internalAuthEmail(studentId: string) {
  return `student.${studentId}@auth.sige.local`;
}

export async function activateStudentAccessAction(input: unknown) {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { ok: false as const, code: "INVALID_ARGUMENT" as const };

  const access = await getCurrentAccessContext();
  if (
    !access.memberships.some(
      (m) =>
        m.school_id === parsed.data.schoolId &&
        m.permissions.includes("student.access.manage"),
    )
  ) {
    return { ok: false as const, code: "FORBIDDEN" as const };
  }

  const admin = createSupabaseAdminClient();
  const { data: student, error: studentError } = await admin
    .from("students")
    .select("id, school_id, person_id, school_number, status")
    .eq("id", parsed.data.studentId)
    .eq("school_id", parsed.data.schoolId)
    .single();

  if (studentError || !student)
    return { ok: false as const, code: "STUDENT_NOT_FOUND" as const };
  if (student.status !== "ACTIVE")
    return { ok: false as const, code: "STUDENT_NOT_ACTIVE" as const };

  const { data: existing } = await admin
    .from("app_accounts")
    .select("id, active")
    .eq("person_id", student.person_id)
    .maybeSingle();

  if (existing?.id)
    return { ok: false as const, code: "ACCOUNT_ALREADY_EXISTS" as const };

  const { data: role } = await admin
    .from("roles")
    .select("id")
    .eq("code", "STUDENT")
    .single();

  if (!role) return { ok: false as const, code: "ROLE_NOT_CONFIGURED" as const };

  const password = generateTemporaryPassword();
  const email = internalAuthEmail(student.id);
  let authUserId: string | undefined;
  let accountId: string | undefined;

  try {
    const { data: auth, error: authError } =
      await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });

    if (authError || !auth.user) throw new Error("AUTH_USER_CREATE_FAILED");
    authUserId = auth.user.id;

    const { data: account, error: accountError } = await admin
      .from("app_accounts")
      .insert({
        auth_user_id: auth.user.id,
        person_id: student.person_id,
        active: true,
        first_access_required: true,
        credential_issued_at: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (accountError || !account) throw new Error("ACCOUNT_CREATE_FAILED");
    accountId = account.id;

    const { error: roleError } = await admin.from("account_roles").insert({
      app_account_id: account.id,
      role_id: role.id,
      school_id: student.school_id,
      active: true,
      starts_on: new Date().toISOString().slice(0, 10),
    });

    if (roleError) throw new Error("ROLE_ASSIGN_FAILED");

    revalidatePath(`/alunos/${student.id}`);
    revalidatePath("/alunos");

    return {
      ok: true as const,
      result: {
        studentId: student.id,
        accountId: account.id,
        schoolNumber: student.school_number,
        temporaryPassword: password,
      },
    };
  } catch (error) {
    if (accountId) {
      await admin.from("account_roles").delete().eq("app_account_id", accountId);
      await admin.from("app_accounts").delete().eq("id", accountId);
    }
    if (authUserId) {
      await admin.auth.admin.deleteUser(authUserId).catch(() => undefined);
    }

    return {
      ok: false as const,
      code:
        error instanceof Error
          ? error.message
          : "STUDENT_ACCESS_PROVISIONING_FAILED",
    };
  }
}
