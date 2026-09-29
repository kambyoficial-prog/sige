import { notFound } from "next/navigation";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { getClassGroup, getClassGroupStudents, getClassGroupTeachers, getCourseOfferings, searchTeacherDirectory } from "@/lib/sige/queries";
import { GenerateOfferingsButton, TeacherAssignmentForm, DirectorAssignmentForm } from "@/components/classes/offering-actions";

export default async function ClassDetailPage({params}:{params:Promise<{id:string}>}){
 const{id}=await params;
 const access=await getCurrentAccessContext();
 const canManage=access.memberships.some((m)=>m.permissions.includes("operations.manage"));
 const [group,students,teachers,offerings,allTeachers]=await Promise.all([getClassGroup(id),getClassGroupStudents(id),getClassGroupTeachers(id),getCourseOfferings(id),searchTeacherDirectory()]);
 if(!group)notFound();
 return <div className="space-y-8">
  <PageHeader title={group.name||group.section_code} description={`${group.academic_year_label} · ${group.grade_level_name} · ${group.academic_cycle_name}`}/>
  <section className="grid gap-4 md:grid-cols-4">{[["Estado",group.status],["Alunos",String(group.student_count)],["Capacidade",group.capacity?String(group.capacity):"Sem limite"],["Diretor",group.director_teacher_name||"Não atribuído"]].map(([l,v])=><div key={l as string} className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">{l}</p><p className="mt-2 font-medium">{v}</p></div>)}</section>
  <section className="rounded-xl border border-border bg-card p-6 space-y-4"><div><h2 className="font-semibold">Diretor de turma</h2><p className="text-sm text-muted-foreground">O servidor só aceita um professor que já lecione uma disciplina desta turma.</p></div>{group.director_teacher_name?<p className="text-sm">{group.director_teacher_name}</p>:canManage&&teachers.length?<DirectorAssignmentForm classGroupId={group.id} teachers={teachers.map(t=>({id:t.teacher_id,full_name:t.teacher_name}))}/>:<p className="text-sm text-muted-foreground">{canManage?"Primeiro atribua um professor a uma disciplina desta turma.":"Sem permissão para alterar a direção da turma."}</p>}</section>
  <section className="rounded-xl border border-border bg-card p-6 space-y-4"><div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between"><div><h2 className="font-semibold">Disciplinas e docentes</h2><p className="text-sm text-muted-foreground">As ofertas são derivadas do currículo configurado para a classe.</p></div>{canManage&&!offerings.length?<GenerateOfferingsButton classGroupId={group.id}/>:null}</div>{offerings.length?<div className="space-y-3">{offerings.map(o=><div key={o.id} className="rounded-lg border border-border p-4"><div className="flex items-start justify-between gap-4"><div><p className="font-medium">{o.subject_name}</p><p className="text-xs text-muted-foreground">{o.subject_code} · {o.status}</p></div><Badge variant="secondary">{o.teacher_name||"Sem professor"}</Badge></div>{canManage&&!o.teacher_id?<div className="mt-4"><TeacherAssignmentForm courseOfferingId={o.id} teachers={allTeachers.filter((t)=>t.school_id===group.school_id).map(t=>({id:t.id,full_name:t.full_name}))}/></div>:null}</div>)}</div>:<p className="text-sm text-muted-foreground">Nenhuma oferta gerada. Verifique primeiro a configuração curricular.</p>}</section>
  <section className="space-y-3"><div><h2 className="font-semibold">Alunos</h2><p className="text-sm text-muted-foreground">Lista atual de alunos colocados nesta turma.</p></div><div className="overflow-x-auto rounded-lg border border-border"><table className="w-full text-sm"><thead><tr className="border-b border-border text-left"><th className="px-4 py-3">N.º</th><th className="px-4 py-3">Aluno</th><th className="px-4 py-3">Estado</th></tr></thead><tbody>{students.map(s=><tr key={s.student_id} className="border-b border-border last:border-0"><td className="px-4 py-3">{s.school_number}</td><td className="px-4 py-3">{s.student_name}</td><td className="px-4 py-3">{s.status}</td></tr>)}</tbody></table></div></section>
 </div>
}
