"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { Input } from "@/components/ui/input";
import { errorMessage } from "@/lib/sige/presentation";
import { enrollStudentAction } from "@/lib/sige/enrollment-actions";

const schema=z.object({
  studentId:z.string().uuid("Selecione o aluno."),
  academicYearId:z.string().uuid("Selecione o ano letivo."),
  gradeLevelId:z.string().uuid("Selecione a classe."),
  entryType:z.enum(["INITIAL","TRANSFER_IN","REENTRY","RENEWAL"]),
  enrolledOn:z.string().min(10,"Indique a data."),
});
type Values=z.infer<typeof schema>;

export function EnrollmentForm({students,years,grades}:{students:Array<{id:string;full_name:string;school_number:string}>;years:Array<{id:string;label:string;status:string}>;grades:Array<{id:string;name:string;code:string}>}) {
  const router=useRouter(); const [pending,startTransition]=useTransition();
  const form=useForm<Values>({resolver:zodResolver(schema),defaultValues:{studentId:"",academicYearId:years.find(y=>y.status==="OPEN")?.id??"",gradeLevelId:"",entryType:"INITIAL",enrolledOn:new Date().toISOString().slice(0,10)}});
  function submit(values:Values){startTransition(async()=>{const r=await enrollStudentAction(values);if(!r.ok){toast.error(errorMessage(r.code as never));return;}const p=r.result as {enrollment_id?:string};toast.success("Matrícula criada.");router.push(p.enrollment_id?`/matriculas/${p.enrollment_id}`:"/matriculas");});}
  return <form onSubmit={form.handleSubmit(submit)} className="space-y-6">
    <FormField id="studentId" label="Aluno" required error={form.formState.errors.studentId?.message}><select id="studentId" {...form.register("studentId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar aluno</option>{students.map(s=><option key={s.id} value={s.id}>{s.full_name} · {s.school_number}</option>)}</select></FormField>
    <div className="grid gap-5 md:grid-cols-2">
      <FormField id="academicYearId" label="Ano letivo" required error={form.formState.errors.academicYearId?.message}><select id="academicYearId" {...form.register("academicYearId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar ano</option>{years.map(y=><option key={y.id} value={y.id}>{y.label} · {y.status}</option>)}</select></FormField>
      <FormField id="gradeLevelId" label="Classe" required error={form.formState.errors.gradeLevelId?.message}><select id="gradeLevelId" {...form.register("gradeLevelId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar classe</option>{grades.map(g=><option key={g.id} value={g.id}>{g.name}</option>)}</select></FormField>
      <FormField id="entryType" label="Tipo de entrada" required><select id="entryType" {...form.register("entryType")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="INITIAL">Inicial</option><option value="TRANSFER_IN">Transferência de entrada</option><option value="REENTRY">Reingresso</option></select></FormField>
      <FormField id="enrolledOn" label="Data da matrícula" required error={form.formState.errors.enrolledOn?.message}><Input id="enrolledOn" type="date" {...form.register("enrolledOn")} /></FormField>
    </div>
    <div className="flex justify-end gap-2 border-t border-border pt-5"><Button type="button" variant="outline" onClick={()=>router.back()}>Cancelar</Button><Button type="submit" disabled={pending}>{pending?"A processar…":"Criar matrícula"}</Button></div>
  </form>;
}
