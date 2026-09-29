"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function signInWithPassword(input: { email: string; password: string }) {
  const email = input.email.trim().toLowerCase();

  if (!email || !input.password) {
    return { ok: false as const, code: "INVALID_CREDENTIALS" as const };
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword({
    email,
    password: input.password,
  });

  if (error) {
    return { ok: false as const, code: "INVALID_CREDENTIALS" as const };
  }

  revalidatePath("/", "layout");
  return { ok: true as const };
}

export async function signOut() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
  redirect("/login");
}
