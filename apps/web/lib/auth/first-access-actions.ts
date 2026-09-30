"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
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

  const admin = createSupabaseAdminClient();
  const { data: account } = await admin
    .from("app_accounts")
    .select("id, person_id, first_access_required, active")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (!account?.active) return { ok: false as const, code: "ACCOUNT_INACTIVE" as const };
  if (!account.first_access_required)
    return { ok: false as const, code: "FIRST_ACCESS_NOT_REQUIRED" as const };

  const { error: passwordError } = await supabase.auth.updateUser({
    password: parsed.data.password,
  });

  if (passwordError)
    return { ok: false as const, code: "PASSWORD_UPDATE_FAILED" as const };

  const { error: accountError } = await admin
    .from("app_accounts")
    .update({
      first_access_required: false,
      activated_at: new Date().toISOString(),
    })
    .eq("id", account.id)
    .eq("auth_user_id", user.id);

  if (accountError)
    return { ok: false as const, code: "ACCOUNT_ACTIVATION_FAILED" as const };

  revalidatePath("/", "layout");
  return { ok: true as const };
}
