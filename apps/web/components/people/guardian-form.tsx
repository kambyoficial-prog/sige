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
import { createGuardianAction } from "@/lib/sige/people-actions";

const schema=z.object({schoolId:z.string().uuid(),studentId:z.string().uuid(),fullName:z.string().trim().min(2),relationship:z.string().optional(),occupation:z.string().optional(),identityNumber:z.string().optional(),address:z.string().optional(),phone:z.string().optional(),gender:z.string().optional(),birthDate:z.string().optional(),nationalId:z.string().optional(),isPrimary:z.boolean().optional(),livesWithStudent:z.boolean().optional()});
type Values=z.infer<typeof schema>;

export function GuardianForm({schoolId,studentId}:{schoolId:string;studentId:string}){
 const router=useRouter();const[pending,startTransition]=useTransition();const form=useForm<Values>({resolver:zodResolver(schema),defaultValues:{schoolId,studentId,isPrimary:false,livesWithStudent:false}});
 function submit(v:Values){startTransition(async()=>{const r=await createGuardianAction(v);if(!r.ok){toast.error(errorMessage(r.code as never));return;}toast.success("Encarregado associado.");router.push(`/alunos/${studentId}`);});}
 return <form onSubmit={form.handleSubmit(submit)} className="space-y-6">
  <div className="grid gap-5 md:grid-cols-2">
   <FormField id="fullName" label="Nome completo" required><Input id="fullName" {...form.register("fullName")}/></FormField>
   <FormField id="relationship" label="Relação com o aluno"><Input id="relationship" {...form.register("relationship")}/></FormField>
   <FormField id="occupation" label="Profissão"><Input id="occupation" {...form.register("occupation")}/></FormField>
   <FormField id="identityNumber" label="BI / documento"><Input id="identityNumber" {...form.register("identityNumber")}/></FormField>
   <FormField id="phone" label="Telefone"><Input id="phone" {...form.register("phone")}/></FormField>
   <FormField id="nationalId" label="Identificação nacional"><Input id="nationalId" {...form.register("nationalId")}/></FormField>
   <FormField id="birthDate" label="Data de nascimento"><Input id="birthDate" type="date" {...form.register("birthDate")}/></FormField>
   <FormField id="gender" label="Sexo"><select id="gender" {...form.register("gender")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Não indicado</option><option value="M">Masculino</option><option value="F">Feminino</option></select></FormField>
   <div className="md:col-span-2"><FormField id="address" label="Residência"><Textarea id="address" {...form.register("address")}/></FormField></div>
  </div>
  <div className="grid gap-3 sm:grid-cols-2"><label className="flex items-center gap-2 text-sm"><input type="checkbox" {...form.register("isPrimary")}/> Encarregado principal</label><label className="flex items-center gap-2 text-sm"><input type="checkbox" {...form.register("livesWithStudent")}/> Vive com o aluno</label></div>
  <div className="flex justify-end gap-2 border-t border-border pt-5"><Button type="button" variant="outline" onClick={()=>router.back()}>Cancelar</Button><Button type="submit" disabled={pending}>{pending?"A guardar…":"Associar encarregado"}</Button></div>
 </form>;
}
