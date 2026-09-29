import type { TeacherDirectory } from "@sige/contracts";
import { DirectoryTable } from "@/components/ui/directory-table";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { searchTeacherDirectory } from "@/lib/sige/queries";

export default async function TeachersPage({searchParams}:{searchParams:Promise<{q?:string}>}) {
  const params=await searchParams;
  const search=params.q?.trim()??"";
  const rows: TeacherDirectory[] = await searchTeacherDirectory(search);
  return <div className="space-y-6"><PageHeader title="Professores" description="Diretório institucional dos docentes."/><form method="get" className="flex gap-2"><input name="q" defaultValue={search} placeholder="Pesquisar por nome ou código…" className="h-10 flex-1 rounded-md border border-input bg-background px-3 text-sm sm:max-w-md"/><Button type="submit" variant="outline">Pesquisar</Button></form><DirectoryTable kind="teachers" data={rows}/></div>;
}
