"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function resolveStudentLogin(identifier: string) {
  const admin = createSupabaseAdminClient();
  const { data: student, error } = await admin.from("students").select("id, person_id, status").eq("school_number", identifier.toUpperCase()).maybeSingle();
  if (error || !student || student.status !== "ACTIVE") return null;
  const { data: account } = await admin.from("app_accounts").select("id, auth_user_id, active, first_access_required").eq("person_id", student.person_id).eq("active", true).maybeSingle();
  if (!account) return null;
  const { data: roles } = await admin.from("account_roles").select("role_id, roles!inner(code)").eq("app_account_id", account.id).eq("active", true);
  if (!roles?.some((row: any) => row.roles?.code === "STUDENT")) return null;
  const { data: authUser } = await admin.auth.admin.getUserById(account.auth_user_id);
  return authUser.user?.email ?? null;
}

export async function signInWithPassword(input: { identifier: string; password: string }) {
  const identifier = input.identifier.trim();
  if (!identifier || !input.password) return { ok: false as const, code: "INVALID_CREDENTIALS" as const };
  let email = identifier.toLowerCase();
  if (!identifier.includes("@")) email = (await resolveStudentLogin(identifier)) ?? "";
  if (!email) return { ok: false as const, code: "INVALID_CREDENTIALS" as const };

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password: input.password });
  if (error || !data.user) return { ok: false as const, code: "INVALID_CREDENTIALS" as const };

  const admin = createSupabaseAdminClient();
  const { data: account } = await admin
    .from("app_accounts")
    .select("first_access_required")
    .eq("auth_user_id", data.user.id)
    .eq("active", true)
    .maybeSingle();

  revalidatePath("/", "layout");
  return { ok: true as const, firstAccessRequired: account?.first_access_required === true };
}

export async function signOut() {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signOut();
  if (error) return { ok: false as const };
  revalidatePath("/", "layout");
  return { ok: true as const };
}

export async function signOutAndRedirect() {
  await signOut();
  redirect("/login");
}
