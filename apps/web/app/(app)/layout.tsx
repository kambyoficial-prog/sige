import { redirect } from "next/navigation";
import { SigeApplicationError } from "@sige/contracts";
import { AppShell } from "@/components/app-shell";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function AuthenticatedLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  let access;
  try {
    access = await getCurrentAccessContext();
  } catch (error) {
    if (error instanceof SigeApplicationError && error.code === "AUTH_REQUIRED") redirect("/login");
    throw error;
  }
  if (!access.memberships.length) redirect("/acesso-negado");

  const supabase = await createSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();
  if (userData.user) {
    const admin = createSupabaseAdminClient();
    const { data: account } = await admin
      .from("app_accounts")
      .select("first_access_required")
      .eq("auth_user_id", userData.user.id)
      .eq("active", true)
      .maybeSingle();
    if (account?.first_access_required) redirect("/primeiro-acesso");
  }

  const permissions = new Set(access.memberships.flatMap(m => m.permissions));
  const roles = new Set(access.memberships.flatMap(m => m.roles.map(r => r.code)));
  const schoolName = access.memberships.length === 1 ? access.memberships[0].school_name : "SIGE";
  return <AppShell permissions={permissions} roles={roles} personName={access.person?.full_name ?? "Utilizador"} schoolName={schoolName} academicYearLabel={undefined}>{children}</AppShell>;
}
