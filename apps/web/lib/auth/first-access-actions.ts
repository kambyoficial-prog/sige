"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const schema = z.object({
  password: z.string().min(10).max(128),
});

export async function completeFirstAccessAction(input: unknown) {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { ok: false as const, code: "INVALID_PASSWORD" as const };

  const supabase = await createSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();
  const user = userData.user;
  if (!user) return { ok: false as const, code: "UNAUTHENTICATED" as const };

  const { data: account, error: accountError } = await supabase
    .from("app_accounts")
    .select("id, person_id, first_access_required, active")
    .eq("active", true)
    .maybeSingle();

  if (accountError) return { ok: false as const, code: "ACCOUNT_STATE_FAILED" as const };
  if (!account?.active) return { ok: false as const, code: "ACCOUNT_INACTIVE" as const };
  if (!account.first_access_required)
    return { ok: false as const, code: "FIRST_ACCESS_NOT_REQUIRED" as const };

  const { error: passwordError } = await supabase.auth.updateUser({
    password: parsed.data.password,
  });

  if (passwordError)
    return { ok: false as const, code: "PASSWORD_UPDATE_FAILED" as const };

  const { data: activated, error: activationError } = await supabase.rpc(
    "complete_first_access_account",
  );

  if (activationError || !activated)
    return { ok: false as const, code: "ACCOUNT_ACTIVATION_FAILED" as const };

  revalidatePath("/", "layout");
  return { ok: true as const };
}
