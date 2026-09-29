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
import { createClassGroupAction } from "@/lib/sige/class-actions";

const schema=z.object({academicYearId:z.string().uuid(),gradeLevelId:z.string().uuid(),sectionCode:z.string().trim().min(1),pathwayId:z.string().optional(),shift:z.string().optional(),capacity:z.coerce.number().int().positive().optional(),name:z.string().optional()});
type FormInput=z.input<typeof schema>;
type Values=z.output<typeof schema>;

export function ClassForm({years,grades}:{years:Array<{id:string;label:string;status:string}>;grades:Array<{id:string;name:string}>}){
 const router=useRouter();const[pending,startTransition]=useTransition();const form=useForm<FormInput, unknown, Values>({resolver:zodResolver(schema),defaultValues:{academicYearId:years.find(y=>y.status==="OPEN")?.id??"",gradeLevelId:"",shift:"MORNING"}});
 function submit(v:Values){startTransition(async()=>{const r=await createClassGroupAction(v);if(!r.ok){toast.error(errorMessage(r.code as never));return;}const p=r.result as {class_group_id?:string};toast.success("Turma criada.");router.push(p.class_group_id?`/turmas/${p.class_group_id}`:"/turmas");});}
 return <form onSubmit={form.handleSubmit(submit)} className="space-y-6">
  <div className="grid gap-5 md:grid-cols-2">
   <FormField id="academicYearId" label="Ano letivo" required><select id="academicYearId" {...form.register("academicYearId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar ano</option>{years.map(y=><option key={y.id} value={y.id}>{y.label} · {y.status}</option>)}</select></FormField>
   <FormField id="gradeLevelId" label="Classe" required><select id="gradeLevelId" {...form.register("gradeLevelId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Selecionar classe</option>{grades.map(g=><option key={g.id} value={g.id}>{g.name}</option>)}</select></FormField>
   <FormField id="sectionCode" label="Secção" required description="Código institucional da turma; A/B/C não são regras fixas do sistema."><Input id="sectionCode" {...form.register("sectionCode")} /></FormField>
   <FormField id="name" label="Nome apresentado"><Input id="name" {...form.register("name")} placeholder="Ex.: 8.ª A" /></FormField>
   <FormField id="shift" label="Turno"><select id="shift" {...form.register("shift")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="MORNING">Manhã</option><option value="AFTERNOON">Tarde</option><option value="EVENING">Noite</option><option value="FULL_DAY">Tempo inteiro</option></select></FormField>
   <FormField id="capacity" label="Capacidade"><Input id="capacity" type="number" min="1" {...form.register("capacity", { valueAsNumber: true })} /></FormField>
  </div>
  <div className="flex justify-end gap-2 border-t border-border pt-5"><Button type="button" variant="outline" onClick={()=>router.back()}>Cancelar</Button><Button type="submit" disabled={pending}>{pending?"A criar…":"Criar turma"}</Button></div>
 </form>
}
