import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Button, buttonVariants } from "@/components/ui/button";
import { getAssessmentGradebook, getAcademicYearOptions, getClassGroupDirectory, getCourseOfferings } from "@/lib/sige/queries";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { GradebookGrid } from "@/components/sige/gradebook-grid";

export default async function GradesPage({
  searchParams,
}: {
  searchParams: Promise<{ classGroupId?: string; courseOfferingId?: string; periodId?: string }>;
}) {
  const params = await searchParams;
  const years = await getAcademicYearOptions();
  const classes = await getClassGroupDirectory();
  const classGroupId = params.classGroupId ?? classes[0]?.id;
  const offerings = classGroupId ? await getCourseOfferings(classGroupId) : [];
  const courseOfferingId = params.courseOfferingId ?? offerings[0]?.id;

  const supabase = await createSupabaseServerClient();
  const { data: periods } = await supabase
    .from("assessment_periods")
    .select("id,academic_year_id,code,name,ordinal,status,active")
    .order("ordinal", { ascending: true });

  const selectedOffering = offerings.find((o) => o.id === courseOfferingId);
  const periodId = params.periodId ?? periods?.find((p) => p.academic_year_id === selectedOffering?.academic_year_id)?.id;
  const rows = courseOfferingId && periodId
    ? await getAssessmentGradebook({ course_offering_id: courseOfferingId, assessment_period_id: periodId })
    : [];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notas"
        description="Livro de notas operacional. O lançamento grava avaliações; médias e resultados oficiais são calculados pelo motor académico."
        actions={<Link href="/pautas" className={buttonVariants({ variant: "outline" })}>Ver pautas</Link>}
      />

      <form method="get" className="grid gap-3 rounded-xl border p-4 md:grid-cols-3">
        <label className="space-y-1 text-sm">
          <span className="font-medium">Turma</span>
          <select name="classGroupId" defaultValue={classGroupId} className="h-10 w-full rounded-md border bg-background px-3">
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name || c.section_code} · {c.grade_level_name}</option>)}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-medium">Disciplina</span>
          <select name="courseOfferingId" defaultValue={courseOfferingId} className="h-10 w-full rounded-md border bg-background px-3">
            {offerings.map((o) => <option key={o.id} value={o.id}>{o.subject_name}</option>)}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-medium">Período</span>
          <select name="periodId" defaultValue={periodId} className="h-10 w-full rounded-md border bg-background px-3">
            {(periods ?? []).filter((p) => p.academic_year_id === selectedOffering?.academic_year_id).map((p) => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
        </label>
        <div className="md:col-span-3">
          <Button type="submit">Abrir livro de notas</Button>
        </div>
      </form>

      {selectedOffering ? (
        <div className="flex items-center justify-between rounded-xl border bg-muted/20 px-4 py-3 text-sm">
          <div>
            <div className="font-medium">{selectedOffering.subject_name}</div>
            <div className="text-muted-foreground">{classes.find((c) => c.id === selectedOffering.class_group_id)?.name ?? classes.find((c) => c.id === selectedOffering.class_group_id)?.section_code ?? "Turma"} · {years.find((y) => y.id === selectedOffering.academic_year_id)?.label ?? "Ano letivo"}</div>
          </div>
          <div className="text-right text-xs text-muted-foreground">Notas são lançadas individualmente e publicadas por avaliação.</div>
        </div>
      ) : null}

      <GradebookGrid rows={rows} />
    </div>
  );
}
