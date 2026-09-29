import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Badge } from "@/components/ui/badge";
import { TimetableGrid } from "@/components/sige/timetable-grid";
import { getTeacherProfile, getTeacherTimetable } from "@/lib/sige/queries";

export default async function TeacherProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [profileRows, timetable] = await Promise.all([getTeacherProfile(id), getTeacherTimetable(id)]);
  const teacher = profileRows[0];
  if (!teacher) notFound();

  return (
    <div className="space-y-8">
      <PageHeader
        title={teacher.full_name}
        description={`Código ${teacher.employee_code}`}
        actions={<Link href="/professores" className="text-sm font-medium hover:underline">Voltar aos professores</Link>}
      />
      <section className="grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Estado</p><Badge className="mt-2" variant="secondary">{teacher.status}</Badge></div>
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Telefone</p><p className="mt-2 font-medium">{teacher.phone || "—"}</p></div>
        <div className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">Email</p><p className="mt-2 font-medium">{teacher.email || "—"}</p></div>
      </section>
      <section className="space-y-3">
        <div><h2 className="font-semibold">Atribuições</h2><p className="text-sm text-muted-foreground">Relações docentes atuais derivadas das ofertas pedagógicas.</p></div>
        {teacher.assignments.length ? <div className="overflow-x-auto rounded-lg border border-border"><table className="w-full text-sm"><thead><tr className="border-b border-border text-left"><th className="px-4 py-3">Turma</th><th className="px-4 py-3">Disciplina</th><th className="px-4 py-3">Início</th><th className="px-4 py-3">Fim</th></tr></thead><tbody>{teacher.assignments.map((a) => <tr key={a.course_offering_id} className="border-b border-border last:border-0"><td className="px-4 py-3">{a.class_name || "—"}</td><td className="px-4 py-3">{a.subject_name}</td><td className="px-4 py-3">{a.starts_on}</td><td className="px-4 py-3">{a.ends_on || "—"}</td></tr>)}</tbody></table></div> : <p className="rounded-lg border border-dashed border-border p-5 text-sm text-muted-foreground">Sem atribuições docentes ativas.</p>}
      </section>
      <section className="space-y-3"><div><h2 className="font-semibold">Horário semanal</h2><p className="text-sm text-muted-foreground">Projeção oficial do horário filtrada pelo docente.</p></div><TimetableGrid entries={timetable} /></section>
    </div>
  );
}
