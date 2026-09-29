"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { Eye, EyeOff, Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import * as React from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";

import { signInWithPassword } from "@/lib/auth/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const schema = z.object({
  email: z.string().trim().email("Introduza um email válido."),
  password: z.string().min(1, "Introduza a sua palavra-passe."),
});
type FormValues = z.infer<typeof schema>;

export function LoginForm() {
  const router = useRouter();
  const [showPassword, setShowPassword] = React.useState(false);
  const form = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { email: "", password: "" } });

  async function onSubmit(values: FormValues) {
    const result = await signInWithPassword(values);
    if (!result.ok) {
      toast.error("Não foi possível iniciar sessão", { description: result.code === "INVALID_CREDENTIALS" ? "Email ou palavra-passe incorretos." : "Tente novamente." });
      return;
    }
    toast.success("Sessão iniciada");
    router.replace("/");
    router.refresh();
  }

  const busy = form.formState.isSubmitting;
  return (
    <main className="min-h-svh bg-background px-6 py-10 text-foreground">
      <div className="mx-auto flex min-h-[calc(100svh-5rem)] max-w-md flex-col justify-center">
        <div className="mb-10">
          <p className="text-sm font-semibold tracking-tight">SIGE</p>
          <h1 className="mt-8 text-3xl font-semibold tracking-tight">Entrar no sistema</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">Aceda à gestão da escola com a sua conta institucional.</p>
        </div>

        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input id="email" type="email" autoComplete="username" placeholder="nome@escola.co.mz" aria-invalid={!!form.formState.errors.email} {...form.register("email")} />
            {form.formState.errors.email ? <p className="text-xs text-destructive" role="alert">{form.formState.errors.email.message}</p> : null}
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Palavra-passe</Label>
            <div className="relative">
              <Input id="password" type={showPassword ? "text" : "password"} autoComplete="current-password" className="pr-10" aria-invalid={!!form.formState.errors.password} {...form.register("password")} />
              <button type="button" onClick={() => setShowPassword(v => !v)} className="absolute right-1 top-1 flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground" aria-label={showPassword ? "Ocultar palavra-passe" : "Mostrar palavra-passe"}>
                {showPassword ? <EyeOff size={16} aria-hidden="true" /> : <Eye size={16} aria-hidden="true" />}
              </button>
            </div>
            {form.formState.errors.password ? <p className="text-xs text-destructive" role="alert">{form.formState.errors.password.message}</p> : null}
          </div>
          <Button className="w-full" type="submit" disabled={busy}>{busy ? <Loader2 className="animate-spin" aria-hidden="true" /> : null}{busy ? "A entrar…" : "Entrar"}</Button>
        </form>
        <p className="mt-8 text-center text-xs leading-5 text-muted-foreground">Se não consegue aceder à sua conta, contacte a secretaria ou o administrador do sistema.</p>
      </div>
    </main>
  );
}
