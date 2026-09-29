import { redirect } from "next/navigation";

import { AppShell } from "@/components/app-shell";
import { getCurrentAccessContext } from "@/lib/sige/access";

export default async function AuthenticatedLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  try {
    const access = await getCurrentAccessContext();
    if (!access.memberships.length) redirect("/acesso-negado");
    const permissions = new Set(access.memberships.flatMap(m => m.permissions));
    const school = access.memberships[0];
    return <AppShell permissions={permissions} personName={access.person?.full_name ?? "Utilizador"} schoolName={school.school_name} academicYearLabel={undefined}>{children}</AppShell>;
  } catch (error) {
    if (error instanceof Error && error.message === "AUTH_REQUIRED") redirect("/login");
    throw error;
  }
}
