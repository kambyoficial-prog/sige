"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { errorMessage } from "@/lib/sige/presentation";
import { assignDirectorAction, assignTeacherAction, generateClassOfferingsAction } from "@/lib/sige/class-actions";

export function GenerateOfferingsButton({classGroupId}:{classGroupId:string}){
 const[pending,startTransition]=useTransition();
 return <Button disabled={pending} onClick={()=>startTransition(async()=>{const r=await generateClassOfferingsAction({classGroupId});if(!r.ok){toast.error(errorMessage(r.code as never));return;}toast.success("Disciplinas da turma geradas.");window.location.reload();})}>{pending?"A gerar…":"Gerar disciplinas"}</Button>;
}
export function TeacherAssignmentForm({courseOfferingId,teachers}:{courseOfferingId:string;teachers:Array<{id:string;full_name:string}>}){
 const[pending,startTransition]=useTransition();
 return <form className="flex flex-col gap-2 sm:flex-row" onSubmit={e=>{e.preventDefault();const fd=new FormData(e.currentTarget);startTransition(async()=>{const r=await assignTeacherAction({courseOfferingId,teacherId:String(fd.get("teacherId")),startsOn:String(fd.get("startsOn"))});if(!r.ok)toast.error(errorMessage(r.code as never));else{toast.success("Professor atribuído.");window.location.reload()}})}}><select name="teacherId" required className="h-9 rounded-md border border-input bg-background px-2 text-sm"><option value="">Selecionar professor</option>{teachers.map(t=><option key={t.id} value={t.id}>{t.full_name}</option>)}</select><input name="startsOn" type="date" required defaultValue={new Date().toISOString().slice(0,10)} className="h-9 rounded-md border border-input bg-background px-2 text-sm"/><Button size="sm" type="submit" disabled={pending}>{pending?"A guardar…":"Atribuir"}</Button></form>
}
export function DirectorAssignmentForm({classGroupId,teachers}:{classGroupId:string;teachers:Array<{id:string;full_name:string}>}){
 const[pending,startTransition]=useTransition();
 return <form className="grid gap-2 sm:grid-cols-[1fr_auto_auto]" onSubmit={e=>{e.preventDefault();const fd=new FormData(e.currentTarget);startTransition(async()=>{const r=await assignDirectorAction({classGroupId,teacherId:String(fd.get("teacherId")),startsOn:String(fd.get("startsOn")),reason:String(fd.get("reason")||"")});if(!r.ok)toast.error(errorMessage(r.code as never));else{toast.success("Diretor de turma atribuído.");window.location.reload()}})}}><select name="teacherId" required className="h-9 rounded-md border border-input bg-background px-2 text-sm"><option value="">Selecionar professor</option>{teachers.map(t=><option key={t.id} value={t.id}>{t.full_name}</option>)}</select><input name="startsOn" type="date" required defaultValue={new Date().toISOString().slice(0,10)} className="h-9 rounded-md border border-input bg-background px-2 text-sm"/><Button size="sm" type="submit" disabled={pending}>{pending?"A guardar…":"Atribuir direção"}</Button></form>
}
