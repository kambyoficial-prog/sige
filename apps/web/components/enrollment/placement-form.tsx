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
import { Textarea } from "@/components/ui/textarea";
import { errorMessage } from "@/lib/sige/presentation";
import { placeStudentAction } from "@/lib/sige/enrollment-actions";

const schema=z.object({enrollmentId:z.string().uuid(),classGroupId:z.string().uuid("Selecione a turma."),startsOn:z.string().min(10),reason:z.string().max(240).optional()});
type Values=z.infer<typeof schema>;

export function PlacementForm({enrollmentId,studentId,classes}:{enrollmentId:string;studentId:string;classes:Array<{id:string;name:string|null;section_code:string;status:string;student_count:number;capacity:number|null;pathway_id:string|null;pathway_name:string|null}>}) {
  const router=useRouter(); const [pending,startTransition]=useTransition();
  const form=useForm<Values>({resolver:zodResolver(schema),defaultValues:{enrollmentId,startsOn:new Date().toISOString().slice(0,10),classGroupId:""}});
  function submit(values:Values){startTransition(async()=>{const r=await placeStudentAction(values);if(!r.ok){toast.error(errorMessage(r.code as never));return;}toast.success("Aluno colocado na turma.");router.push(`/alunos/${studentId}?acesso=emitir`);});}
  return <form onSubmit={form.handleSubmit(submit)} className="space-y-5">
    <FormField id="classGroupId" label="Turma" required error={form.formState.errors.classGroupId?.message}><select id="classGroupId" {...form.register("classGroupId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar turma</option>{classes.map(c=><option key={c.id} value={c.id}>{c.name||c.section_code} · {c.student_count}{c.capacity?"/"+c.capacity:""} · {c.status}</option>)}</select></FormField>
    <div className="grid gap-5 md:grid-cols-2"><FormField id="startsOn" label="Início" required><Input id="startsOn" type="date" {...form.register("startsOn")} /></FormField><FormField id="reason" label="Motivo"><Textarea id="reason" {...form.register("reason")} /></FormField></div>
    <Button type="submit" disabled={pending}>{pending?"A processar…":"Colocar na turma"}</Button>
  </form>;
}
