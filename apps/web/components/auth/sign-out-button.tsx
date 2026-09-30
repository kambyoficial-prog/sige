"use client";
import * as React from "react";
import { useFormStatus } from "react-dom";
import { toast } from "sonner";
import { signOut } from "@/lib/auth/actions";
import { Button } from "@/components/ui/button";
function Submit(){const {pending}=useFormStatus();return <Button type="submit" variant="ghost" size="sm" disabled={pending} className="w-full justify-start text-muted-foreground">{pending?"A terminar…":"Terminar sessão"}</Button>}
export function SignOutButton(){return <form action={async()=>{await signOut();toast.success("Sessão terminada.");}}><Submit/></form>}
