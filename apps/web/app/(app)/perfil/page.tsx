import { DirectoryTable } from "@/components/ui/directory-table";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { PageHeader } from "@/components/ui/page-header";
import { Badge } from "@/components/ui/badge";

type MembershipRow = { school_id: string; school_name: string; school_code: string; roles: string; permissions: number };

export default async function ProfilePage() {
  const access = await getCurrentAccessContext();
  const rows: MembershipRow[] = access.memberships.map(m => ({ school_id: m.school_id, school_name: m.school_name, school_code: m.school_code, roles: m.roles.map(r => r.name).join(", "), permissions: m.permissions.length }));
  return <div className="space-y-8"><PageHeader title="Perfil" description="Identidade e associações de acesso da conta autenticada." /><section className="grid gap-4 md:grid-cols-2"><div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Nome</p><p className="mt-1 font-medium">{access.person?.full_name ?? "—"}</p></div><div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Email</p><p className="mt-1 font-medium">{access.person?.email ?? "—"}</p></div></section><section className="space-y-3"><div className="flex items-center justify-between"><div><h2 className="text-base font-semibold">Acessos institucionais</h2><p className="text-sm text-muted-foreground">As permissões são informativas; cada operação volta a ser autorizada no servidor.</p></div><Badge variant="secondary">{rows.length} associação(ões)</Badge></div><DirectoryTable kind="profile" data={rows} emptyTitle="Sem associações" emptyDescription="A conta autenticou-se, mas não tem associações institucionais ativas." /></section></div>;
}
