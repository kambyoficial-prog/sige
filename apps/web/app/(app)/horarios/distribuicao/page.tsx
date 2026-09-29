import { getAcademicYearOptions, getClassGroupDirectory, getClassGroupTeachers, getCourseOfferings } from "@/lib/sige/queries";
import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/ui/page-header";
import { ScheduleEntryForm } from "@/components/sige/schedule-entry-form";

async function getPeriodsAndRooms() {
  const { supabase } = await requireAuthenticatedServerClient();
  const [{ data: periods, error: periodsError }, { data: rooms, error: roomsError }] =
    await Promise.all([
      supabase.from("schedule_periods").select("id,code,name,ordinal,starts_at,ends_at").order("ordinal"),
      supabase.from("rooms").select("id,code,name,capacity").order("code"),
    ]);
  if (periodsError) throw periodsError;
  if (roomsError) throw roomsError;
  return { periods: periods ?? [], rooms: rooms ?? [] };
}

export default async function ScheduleDistributionPage({
  searchParams,
}: {
  searchParams: Promise<{ class_id?: string }>;
}) {
  const params = await searchParams;
  const classes = await getClassGroupDirectory();
  const selected = classes.find((item) => item.id === params.class_id) ?? classes[0];
  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.id === selected?.academic_year_id) ?? years[0];
  const [{ periods, rooms }, teachers, offerings] = selected
    ? await Promise.all([
        getPeriodsAndRooms(),
        getClassGroupTeachers(selected.id),
        getCourseOfferings(selected.id),
      ])
    : [{ periods: [], rooms: [] }, [], []];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Distribuição de horários"
        description="Planeamento assistido: a secretaria escolhe a combinação e o banco impede conflitos de turma, professor e sala."
      />

      <div className="flex flex-wrap gap-2">
        <a href="/horarios" className="rounded-lg border border-border px-3 py-2 text-sm hover:bg-muted">Horário por turma</a>
        <a href="/horarios/distribuicao" className="rounded-lg border border-foreground bg-foreground px-3 py-2 text-sm text-background">Distribuir</a>
        <a href="/horarios/professor" className="rounded-lg border border-border px-3 py-2 text-sm hover:bg-muted">Professor</a>
        <a href="/horarios/aluno" className="rounded-lg border border-border px-3 py-2 text-sm hover:bg-muted">Aluno</a>
      </div>

      {!selected || !year ? (
        <div className="rounded-xl border border-border bg-card p-8 text-sm text-muted-foreground">
          Configure primeiro uma turma e um ano letivo.
        </div>
      ) : (
        <>
          <form method="get" className="rounded-xl border border-border bg-card p-4">
            <label className="block max-w-xl space-y-1.5">
              <span className="text-sm font-medium">Turma</span>
              <select name="class_id" defaultValue={selected.id} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                {classes.map((item) => (
                  <option key={item.id} value={item.id}>{item.name || item.section_code} · {item.grade_level_name}</option>
                ))}
              </select>
            </label>
            <button type="submit" className="mt-3 h-10 rounded-md bg-foreground px-4 text-sm font-medium text-background">Carregar</button>
          </form>

          <ScheduleEntryForm
            academicYearId={year.id}
            classGroupId={selected.id}
            validFrom={year.starts_on}
            offerings={offerings}
            teachers={teachers}
            periods={periods}
            rooms={rooms}
          />
        </>
      )}
    </div>
  );
}
