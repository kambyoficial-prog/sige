import { notFound } from "next/navigation";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { PlacementForm } from "@/components/enrollment/placement-form";
import { getClassGroupDirectory, getEnrollment } from "@/lib/sige/queries";

export default async function EnrollmentDetailPage({params}:{params:Promise<{id:string}>}) {
  const {id}=await params; const access=await getCurrentAccessContext(); const canManage=access.memberships.some((m)=>m.permissions.includes("enrollment.manage")); const enrollment=await getEnrollment(id); if(!enrollment) notFound();
  const classes=await getClassGroupDirectory(enrollment.academic_year_id);
  return <div className="space-y-8"><PageHeader title={`Matrícula · ${enrollment.student_name}`} description={`${enrollment.academic_year_label} · ${enrollment.grade_level_name}`}/><section className="grid gap-4 md:grid-cols-4">{[["Estado",enrollment.status],["Entrada",enrollment.entry_type],["Data",enrollment.enrolled_on],["Turma",enrollment.class_name||"Sem turma"]].map(([l,v])=><div key={l as string} className="rounded-lg border border-border bg-card p-5"><p className="text-xs text-muted-foreground">{l}</p><p className="mt-2 font-medium">{v}</p></div>)}</section>{canManage&&enrollment.status==="ACTIVE"&&!enrollment.class_group_id?<section className="rounded-xl border border-border bg-card p-6 space-y-5"><div><h2 className="font-semibold">Colocação na turma</h2><p className="text-sm text-muted-foreground">A colocação verifica escola, ano, classe, capacidade e datas no servidor.</p></div><PlacementForm enrollmentId={enrollment.id} studentId={enrollment.student_id} classes={classes.filter(c=>["OPEN","ACTIVE"].includes(c.status) && c.grade_level_id === enrollment.grade_level_id && (!c.pathway_id || c.pathway_id === enrollment.pathway_id)).map(c=>({id:c.id,name:c.name,section_code:c.section_code,status:c.status,student_count:c.student_count,capacity:c.capacity,pathway_id:c.pathway_id,pathway_name:c.pathway_name}))}/></section>:null}</div>;
}
