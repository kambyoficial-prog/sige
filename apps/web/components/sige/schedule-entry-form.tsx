"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createScheduleEntryAction } from "@/lib/sige/schedule-actions";
import { Button } from "@/components/ui/button";

type Offering = { id: string; subject_name: string; subject_code: string };
type Teacher = { teacher_assignment_id: string; teacher_id: string; teacher_name: string; course_offering_id: string; subject_name: string | null };
type Period = { id: string; code: string; name: string; ordinal: number; starts_at: string; ends_at: string };
type Room = { id: string; code: string; name: string; capacity: number | null };

export function ScheduleEntryForm({
  academicYearId, classGroupId, validFrom, offerings, teachers, periods, rooms,
}: {
  academicYearId: string; classGroupId: string; validFrom: string;
  offerings: Offering[]; teachers: Teacher[]; periods: Period[]; rooms: Room[];
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [offeringId, setOfferingId] = useState(offerings[0]?.id ?? "");
  const [teacherAssignmentId, setTeacherAssignmentId] = useState(
    teachers.find((item) => item.course_offering_id === offerings[0]?.id)?.teacher_assignment_id ?? "",
  );
  const [day, setDay] = useState("1");
  const [periodId, setPeriodId] = useState(periods[0]?.id ?? "");
  const [roomId, setRoomId] = useState("");
  const teachersForOffering = teachers.filter((item) => item.course_offering_id === offeringId);

  function chooseOffering(value: string) {
    setOfferingId(value);
    setTeacherAssignmentId(teachers.find((item) => item.course_offering_id === value)?.teacher_assignment_id ?? "");
  }

  function submit() {
    const assignment = teachersForOffering.find((item) => item.teacher_assignment_id === teacherAssignmentId);
    if (!assignment) { setError("A oferta selecionada não tem uma atribuição docente válida."); return; }
    startTransition(async () => {
      const result = await createScheduleEntryAction({
        academicYearId, classGroupId, courseOfferingId: offeringId,
        teacherAssignmentId, teacherId: assignment.teacher_id,
        roomId: roomId || undefined, periodId, dayOfWeek: Number(day), validFrom,
      });
      if (!result.ok) { setError(result.code); return; }
      setError(null);
      router.push("/horarios?class_id=" + classGroupId);
    });
  }

  return (
    <section className="rounded-xl border border-border bg-card p-5">
      <div className="mb-5">
        <h2 className="font-semibold">Adicionar aula</h2>
        <p className="mt-1 text-sm text-muted-foreground">A validação final é transacional no PostgreSQL.</p>
      </div>
      {error ? <div role="alert" className="mb-4 rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{error}</div> : null}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <label className="space-y-1.5 text-sm"><span className="font-medium">Disciplina</span>
          <select value={offeringId} onChange={(e) => chooseOffering(e.target.value)} className="h-10 w-full rounded-md border border-input bg-background px-3">
            {offerings.map((item) => <option key={item.id} value={item.id}>{item.subject_name} · {item.subject_code}</option>)}
          </select>
        </label>
        <label className="space-y-1.5 text-sm"><span className="font-medium">Professor</span>
          <select value={teacherAssignmentId} onChange={(e) => setTeacherAssignmentId(e.target.value)} className="h-10 w-full rounded-md border border-input bg-background px-3">
            {teachersForOffering.map((item) => <option key={item.teacher_assignment_id} value={item.teacher_assignment_id}>{item.teacher_name}</option>)}
          </select>
        </label>
        <label className="space-y-1.5 text-sm"><span className="font-medium">Dia</span>
          <select value={day} onChange={(e) => setDay(e.target.value)} className="h-10 w-full rounded-md border border-input bg-background px-3">
            <option value="1">Segunda-feira</option><option value="2">Terça-feira</option><option value="3">Quarta-feira</option><option value="4">Quinta-feira</option><option value="5">Sexta-feira</option><option value="6">Sábado</option>
          </select>
        </label>
        <label className="space-y-1.5 text-sm"><span className="font-medium">Período</span>
          <select value={periodId} onChange={(e) => setPeriodId(e.target.value)} className="h-10 w-full rounded-md border border-input bg-background px-3">
            {periods.map((item) => <option key={item.id} value={item.id}>{item.ordinal}. {item.name} ({item.starts_at}–{item.ends_at})</option>)}
          </select>
        </label>
        <label className="space-y-1.5 text-sm"><span className="font-medium">Sala</span>
          <select value={roomId} onChange={(e) => setRoomId(e.target.value)} className="h-10 w-full rounded-md border border-input bg-background px-3">
            <option value="">Sem sala definida</option>
            {rooms.map((item) => <option key={item.id} value={item.id}>{item.code} · {item.name}</option>)}
          </select>
        </label>
      </div>
      <div className="mt-5 flex justify-end">
        <Button type="button" disabled={pending || !offeringId || !teacherAssignmentId || !periodId} onClick={submit}>
          {pending ? "A guardar…" : "Adicionar ao horário"}
        </Button>
      </div>
    </section>
  );
}
