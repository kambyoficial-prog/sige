"use client";
import { useRouter } from "next/navigation";
import { useFormStatus } from "react-dom";
import { toast } from "sonner";
import { signOut } from "@/lib/auth/actions";
import { Button } from "@/components/ui/button";
function Submit(){const {pending}=useFormStatus();return <Button type="submit" variant="ghost" size="sm" disabled={pending} className="w-full justify-start text-muted-foreground">{pending?"A terminar…":"Terminar sessão"}</Button>}
export function SignOutButton(){const router=useRouter();return <form action={async()=>{const r=await signOut();if(!r.ok){toast.error("Não foi possível terminar a sessão.");return;}toast.success("Sessão terminada.");router.replace("/login");router.refresh();}}><Submit/></form>}
