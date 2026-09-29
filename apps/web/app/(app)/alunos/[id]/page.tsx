import Link from "next/link";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getStudentProfile, getStudentEnrollmentHistory } from "@/lib/sige/queries";
import { cn } from "@/lib/utils";

export default async function StudentProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const access = await getCurrentAccessContext();
  const canManage = access.memberships.some((m) => m.permissions.includes("enrollment.manage"));
  const [profileRows, enrollmentRows] = await Promise.all([
    getStudentProfile(id),
    getStudentEnrollmentHistory(id),
  ]);
  const student = profileRows[0];
  if (!student) notFound();
  const history = enrollmentRows;

  return (
    <div className="space-y-8">
      <PageHeader title={student.full_name} description={`N.º ${student.school_number}`} actions={<div className="flex gap-2">{canManage?<Link href={`/alunos/${student.id}/encarregados/novo`} className={cn(buttonVariants())}>Novo encarregado</Link>:null}<Link href="/matriculas" className={cn(buttonVariants({ variant: "outline" }))}>Ver matrículas</Link></div>} />
      <section className="grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Estado</p><Badge className="mt-2" variant="secondary">{student.status}</Badge></div>
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Turma atual</p><p className="mt-2 font-medium">{student.class_name ?? "Sem turma"}</p></div>
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Ano letivo</p><p className="mt-2 font-medium">{student.academic_year_label ?? "—"}</p></div>
      </section>
      <section className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-xl border border-border bg-card p-6 space-y-5"><div><h2 className="font-semibold">Dados pessoais</h2><p className="text-sm text-muted-foreground">Leitura do registo institucional.</p></div><dl className="grid gap-4 sm:grid-cols-2">{[["Sexo",student.gender],["Nascimento",student.birth_date],["Telefone",student.phone],["Email",student.email],["Residência",student.address ?? null]].map(([label,value]) => <div key={label as string}><dt className="text-xs text-muted-foreground">{label}</dt><dd className="mt-1 text-sm">{value || "—"}</dd></div>)}</dl></div>
        <div className="rounded-xl border border-border bg-card p-6 space-y-5"><div><h2 className="font-semibold">Encarregados</h2><p className="text-sm text-muted-foreground">Relações familiares associadas ao aluno.</p></div>{student.guardians.length ? <div className="space-y-3">{student.guardians.map((g) => <div key={g.id} className="rounded-lg border border-border p-4"><div className="flex items-center justify-between gap-3"><p className="font-medium">{g.full_name}</p>{g.is_primary ? <Badge variant="secondary">Principal</Badge> : null}</div><p className="mt-1 text-sm text-muted-foreground">{g.relationship || "Relação não indicada"} · {g.phone || "Sem telefone"}</p></div>)}</div> : <p className="text-sm text-muted-foreground">Nenhum encarregado associado.</p>}</div>
      </section>
      <section className="space-y-3"><div><h2 className="font-semibold">Histórico de matrículas</h2><p className="text-sm text-muted-foreground">Episódios preservados sem apagar histórico.</p></div><div className="overflow-x-auto rounded-lg border border-border"><table className="w-full text-sm"><thead><tr className="border-b border-border text-left"><th className="px-4 py-3">Ano</th><th className="px-4 py-3">Classe</th><th className="px-4 py-3">Entrada</th><th className="px-4 py-3">Estado</th><th className="px-4 py-3">Turma</th></tr></thead><tbody>{history.map((row) => <tr key={row.id} className="border-b border-border last:border-0"><td className="px-4 py-3">{row.academic_year_label}</td><td className="px-4 py-3">{row.grade_level_name}</td><td className="px-4 py-3">{row.entry_type}</td><td className="px-4 py-3">{row.status}</td><td className="px-4 py-3">{row.class_name || "Sem turma"}</td></tr>)}</tbody></table></div></section>
    </div>
  );
}
