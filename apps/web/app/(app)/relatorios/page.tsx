import { PageHeader } from "@/components/ui/page-header";
import { getAcademicYearOptions } from "@/lib/sige/queries";
import { getReportDemographics,getReportEnrollmentStatus,getReportEnrollmentGrade,getReportClassCapacity,getReportFinanceSummary,getReportAcademicOutcomes } from "@/lib/sige/report-queries";

export default async function ReportsPage(){
 const years=await getAcademicYearOptions(); const year=years.find(y=>y.status==="OPEN")??years[0];
 const [gender,status,grades,classes,finance,outcomes]=await Promise.all([getReportDemographics(),getReportEnrollmentStatus(year?.id),getReportEnrollmentGrade(year?.id),getReportClassCapacity(year?.id),getReportFinanceSummary(year?.id),getReportAcademicOutcomes(year?.id)]);
 const card=(title:string,value:string,meta:string)=><div className="rounded-xl border p-5"><div className="text-sm text-muted-foreground">{title}</div><div className="mt-2 text-2xl font-semibold">{value}</div><div className="mt-1 text-xs text-muted-foreground">{meta}</div></div>;
 const total=(gender as any[]).reduce((n,r)=>n+Number(r.student_count??0),0);
 const male=(gender as any[]).find(r=>String(r.gender).toUpperCase().startsWith("M"))?.student_count??0;
 const female=(gender as any[]).find(r=>String(r.gender).toUpperCase().startsWith("F"))?.student_count??0;
 const charged=Number((finance as any[])[0]?.charged_amount??0),paid=Number((finance as any[])[0]?.paid_amount??0);
 return <div className="space-y-8"><PageHeader title="Relatórios" description={year?String(`Indicadores consolidados de ${year.label}.`):"Indicadores consolidados do sistema."}/>
 <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{card("Alunos",String(total),"cadastro atual")}{card("Masculino",String(male),"por género")}{card("Feminino",String(female),"por género")}{card("Saldo financeiro",`${(charged-paid).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT`,"obrigações menos pagamentos confirmados")}</section>
 <section className="grid gap-6 lg:grid-cols-2">
  <div className="rounded-xl border p-5"><h2 className="font-semibold">Matrículas por classe</h2><div className="mt-4 space-y-2">{(grades as any[]).map(r=><div key={String(r.grade_level_id)} className="flex justify-between border-b py-2 text-sm"><span>{String(r.grade_name)}</span><strong>{String(r.enrollment_count)}</strong></div>)}</div></div>
  <div className="rounded-xl border p-5"><h2 className="font-semibold">Estado das matrículas</h2><div className="mt-4 space-y-2">{(status as any[]).map(r=><div key={String(r.status)} className="flex justify-between border-b py-2 text-sm"><span>{String(r.status)}</span><strong>{String(r.enrollment_count)}</strong></div>)}</div></div>
  <div className="rounded-xl border p-5"><h2 className="font-semibold">Turmas e capacidade</h2><div className="mt-4 space-y-2">{(classes as any[]).map(r=><div key={String(r.class_group_id)} className="flex justify-between border-b py-2 text-sm"><span>{String(r.name)}</span><span>{String(r.placed_count)}/{String(r.capacity)}</span></div>)}</div></div>
  <div className="rounded-xl border p-5"><h2 className="font-semibold">Resultados publicados</h2><div className="mt-4 space-y-2">{(outcomes as any[]).map(r=><div key={String(r.result_type)} className="flex justify-between border-b py-2 text-sm"><span>{String(r.result_type)}</span><span>{String(r.approved_count)} aprovados / {String(r.failed_count)} não aprovados</span></div>)}</div></div>
 </section></div>;
}
