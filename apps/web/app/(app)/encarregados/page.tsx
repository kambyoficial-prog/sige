import type { GuardianDirectory } from "@sige/contracts";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { searchGuardianDirectory } from "@/lib/sige/queries";

export default async function GuardiansPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams;
  const search=params.q?.trim()??"";
  const rows: GuardianDirectory[] = await searchGuardianDirectory(search);
  return <div className="space-y-6"><PageHeader title="Encarregados" description="Relações familiares e responsáveis associados aos alunos."/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar por nome ou documento…" className="h-10 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button></form><DirectoryTable kind="guardians" data={rows}/></div>;
}
