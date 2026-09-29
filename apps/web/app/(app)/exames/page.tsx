import { revalidatePath } from "next/cache";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createExamSessionAction, setExamSessionStatusAction } from "@/lib/sige/exam-actions";

async function createSession(formData: FormData) {
  "use server";
  await createExamSessionAction({
    academicYearId: String(formData.get("academicYearId")),
    gradeLevelId: String(formData.get("gradeLevelId")),
    epoch: Number(formData.get("epoch")),
    startsOn: String(formData.get("startsOn")),
    endsOn: String(formData.get("endsOn")),
  });
  revalidatePath("/exames");
}

async function changeStatus(formData: FormData) {
  "use server";
  await setExamSessionStatusAction({
    examSessionId: String(formData.get("examSessionId")),
    status: String(formData.get("status")),
  });
  revalidatePath("/exames");
}

export default async function ExamsPage() {
  const supabase = await createSupabaseServerClient();
  const [{ data: years }, { data: grades }, { data: sessions }] = await Promise.all([
    supabase.from("academic_years").select("id,name").order("starts_on",{ascending:false}),
    supabase.from("grade_levels").select("id,code,name").order("ordinal"),
    supabase.from("exam_sessions").select("id,academic_year_id,grade_level_id,epoch,starts_on,ends_on,status").order("starts_on",{ascending:false}),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader title="Exames" description="Sessões, épocas e governação do processo de exame." />
      <form action={createSession} className="grid gap-3 rounded-xl border p-4 md:grid-cols-5">
        <select name="academicYearId" required className="h-10 rounded-md border bg-background px-3">
          {(years ?? []).map((y) => <option key={y.id} value={y.id}>{y.name}</option>)}
        </select>
        <select name="gradeLevelId" required className="h-10 rounded-md border bg-background px-3">
          {(grades ?? []).map((g) => <option key={g.id} value={g.id}>{g.code} · {g.name}</option>)}
        </select>
        <select name="epoch" defaultValue="1" className="h-10 rounded-md border bg-background px-3">
          <option value="1">1.ª época</option><option value="2">2.ª época</option>
        </select>
        <input name="startsOn" type="date" required className="h-10 rounded-md border bg-background px-3" />
        <div className="flex gap-2">
          <input name="endsOn" type="date" required className="h-10 min-w-0 flex-1 rounded-md border bg-background px-3" />
          <Button type="submit">Criar</Button>
        </div>
      </form>

      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full min-w-[760px] text-sm">
          <thead className="bg-muted/40"><tr className="border-b">
            <th className="px-4 py-3 text-left">Sessão</th><th className="px-4 py-3 text-left">Classe</th>
            <th className="px-4 py-3 text-left">Datas</th><th className="px-4 py-3 text-left">Estado</th><th />
          </tr></thead>
          <tbody>
            {(sessions ?? []).map((s) => {
              const grade = grades?.find((g) => g.id === s.grade_level_id);
              return <tr key={s.id} className="border-b last:border-0">
                <td className="px-4 py-3 font-medium">{s.epoch === 1 ? "1.ª" : "2.ª"} época</td>
                <td className="px-4 py-3">{grade?.code} · {grade?.name}</td>
                <td className="px-4 py-3">{s.starts_on} — {s.ends_on}</td>
                <td className="px-4 py-3">{s.status}</td>
                <td className="px-4 py-3">
                  {s.status === "DRAFT" ? <form action={changeStatus}><input type="hidden" name="examSessionId" value={s.id}/><input type="hidden" name="status" value="OPEN"/><Button size="sm">Abrir</Button></form> : null}
                  {s.status === "OPEN" ? <form action={changeStatus}><input type="hidden" name="examSessionId" value={s.id}/><input type="hidden" name="status" value="CLOSED"/><Button size="sm" variant="outline">Fechar</Button></form> : null}
                </td>
              </tr>;
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
