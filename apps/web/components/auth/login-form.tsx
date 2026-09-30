"use client";
import { zodResolver } from "@hookform/resolvers/zod";
import { Eye, EyeOff, Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import * as React from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import Link from "next/link";
import { signInWithPassword } from "@/lib/auth/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const schema = z.object({
  identifier: z.string().trim().min(1, "Introduza o email ou código de estudante."),
  password: z.string().min(1, "Introduza a sua palavra-passe."),
});
type FormValues = z.infer<typeof schema>;

export function LoginForm() {
  const router = useRouter();
  const [showPassword, setShowPassword] = React.useState(false);
  const form = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { identifier: "", password: "" } });

  async function onSubmit(values: FormValues) {
    const result = await signInWithPassword(values);
    if (!result.ok) {
      toast.error("Não foi possível iniciar sessão", { description: "Email/código ou palavra-passe incorretos." });
      return;
    }
    if (result.firstAccessRequired) {
      router.replace("/primeiro-acesso");
      router.refresh();
      return;
    }
    toast.success("Sessão iniciada");
    router.replace("/");
    router.refresh();
  }

  const busy = form.formState.isSubmitting;
  return <main className="min-h-svh bg-background px-6 py-10 text-foreground"><div className="mx-auto flex min-h-[calc(100svh-5rem)] max-w-md flex-col justify-center"><div className="mb-10"><p className="text-sm font-semibold tracking-tight">SIGE</p><h1 className="mt-8 text-3xl font-semibold tracking-tight">Entrar no sistema</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Funcionários usam a conta institucional. Alunos podem entrar com o código de estudante.</p></div><form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5" noValidate><div className="space-y-2"><Label htmlFor="identifier">Email ou código de estudante</Label><Input id="identifier" autoComplete="username" placeholder="nome@escola.co.mz ou 2026-0012" aria-invalid={!!form.formState.errors.identifier} {...form.register("identifier")} />{form.formState.errors.identifier ? <p className="text-xs text-destructive" role="alert">{form.formState.errors.identifier.message}</p> : null}</div><div className="space-y-2"><div className="flex items-center justify-between"><Label htmlFor="password">Palavra-passe</Label><Link href="/recuperar-acesso" className="text-xs font-medium text-primary hover:underline">Esqueci-me da palavra-passe</Link></div><div className="relative"><Input id="password" type={showPassword ? "text" : "password"} autoComplete="current-password" className="pr-10" aria-invalid={!!form.formState.errors.password} {...form.register("password")} /><button type="button" onClick={() => setShowPassword(v => !v)} className="absolute right-1 top-1 flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground" aria-label={showPassword ? "Ocultar palavra-passe" : "Mostrar palavra-passe"}>{showPassword ? <EyeOff size={16} aria-hidden="true" /> : <Eye size={16} aria-hidden="true" />}</button></div>{form.formState.errors.password ? <p className="text-xs text-destructive" role="alert">{form.formState.errors.password.message}</p> : null}</div><Button className="w-full" type="submit" disabled={busy}>{busy ? <Loader2 className="animate-spin" aria-hidden="true" /> : null}{busy ? "A entrar…" : "Entrar"}</Button></form><p className="mt-8 text-center text-xs leading-5 text-muted-foreground">O aluno recebe o código escolar e uma credencial temporária no momento da activação. A palavra-passe deve ser alterada no primeiro acesso.</p></div></main>;
}
