"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { completeFirstAccessAction } from "@/lib/auth/first-access-actions";

const schema = z
  .object({
    password: z.string().min(10, "Use pelo menos 10 caracteres."),
    confirmation: z.string(),
  })
  .refine((v) => v.password === v.confirmation, {
    path: ["confirmation"],
    message: "As palavras-passe não coincidem.",
  });

type Values = z.infer<typeof schema>;

export function FirstAccessForm() {
  const router = useRouter();
  const form = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { password: "", confirmation: "" },
  });

  async function submit(values: Values) {
    const result = await completeFirstAccessAction(values);
    if (!result.ok) {
      toast.error("Não foi possível concluir o primeiro acesso.");
      return;
    }
    toast.success("Palavra-passe definida.");
    router.replace("/");
    router.refresh();
  }

  const busy = form.formState.isSubmitting;

  return (
    <form onSubmit={form.handleSubmit(submit)} className="space-y-5" noValidate>
      <div className="space-y-2">
        <Label htmlFor="password">Nova palavra-passe</Label>
        <Input id="password" type="password" autoComplete="new-password" {...form.register("password")} />
        {form.formState.errors.password ? (
          <p className="text-xs text-destructive">{form.formState.errors.password.message}</p>
        ) : null}
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirmation">Confirmar palavra-passe</Label>
        <Input id="confirmation" type="password" autoComplete="new-password" {...form.register("confirmation")} />
        {form.formState.errors.confirmation ? (
          <p className="text-xs text-destructive">{form.formState.errors.confirmation.message}</p>
        ) : null}
      </div>
      <Button className="w-full" type="submit" disabled={busy}>
        {busy ? <Loader2 className="animate-spin" aria-hidden="true" /> : null}
        {busy ? "A guardar…" : "Definir palavra-passe"}
      </Button>
    </form>
  );
}
