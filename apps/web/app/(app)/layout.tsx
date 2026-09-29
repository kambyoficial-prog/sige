import { redirect } from "next/navigation";
import { SigeApplicationError } from "@sige/contracts";
import { AppShell } from "@/components/app-shell";
import { getCurrentAccessContext } from "@/lib/sige/access";

export default async function AuthenticatedLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  let access;
  try {
    access = await getCurrentAccessContext();
  } catch (error) {
    if (error instanceof SigeApplicationError && error.code === "AUTH_REQUIRED") redirect("/login");
    throw error;
  }
  if (!access.memberships.length) redirect("/acesso-negado");
  const permissions = new Set(access.memberships.flatMap(m => m.permissions));
  const schoolName = access.memberships.length === 1 ? access.memberships[0].school_name : "SIGE";
  return <AppShell permissions={permissions} personName={access.person?.full_name ?? "Utilizador"} schoolName={schoolName} academicYearLabel={undefined}>{children}</AppShell>;
}
