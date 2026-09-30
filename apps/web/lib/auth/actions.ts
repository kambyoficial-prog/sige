"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function signInWithPassword(input: { identifier: string; password: string }) {
  const identifier = input.identifier.trim();
  if (!identifier || !input.password) return { ok: false as const, code: "INVALID_CREDENTIALS" as const };

  const supabase = await createSupabaseServerClient();
  let email = identifier.toLowerCase();

  if (!identifier.includes("@")) {
    const { data: resolvedEmail, error: resolveError } = await supabase.rpc(
      "resolve_student_login_email",
      { p_school_number: identifier },
    );
    if (resolveError || !resolvedEmail) {
      return { ok: false as const, code: "INVALID_CREDENTIALS" as const };
    }
    email = resolvedEmail;
  }

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password: input.password,
  });
  if (error || !data.user) return { ok: false as const, code: "INVALID_CREDENTIALS" as const };

  const { data: account, error: accountError } = await supabase
    .from("app_accounts")
    .select("first_access_required")
    .eq("active", true)
    .maybeSingle();

  if (accountError) return { ok: false as const, code: "ACCOUNT_STATE_FAILED" as const };

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
