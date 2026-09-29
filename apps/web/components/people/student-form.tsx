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
import { registerStudentAction } from "@/lib/sige/people-actions";

const schema = z.object({
  schoolId: z.string().uuid(),
  schoolNumber: z.string().trim().min(1, "Indique o número do aluno."),
  fullName: z.string().trim().min(2, "Indique o nome completo."),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  gender: z.string().optional(),
  birthDate: z.string().optional(),
  nationalId: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().email("Indique um email válido.").or(z.literal("")),
  address: z.string().optional(),
  admissionDate: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function StudentForm({ schools }: { schools: Array<{ id: string; name: string; code: string }> }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { schoolId: schools[0]?.id ?? "", email: "" },
  });

  function submit(values: FormValues) {
    startTransition(async () => {
      const result = await registerStudentAction(values);
      if (!result.ok) {
        toast.error(errorMessage(result.code as never));
        return;
      }
      const payload = result.result as { student_id?: string };
      toast.success("Aluno registado.");
      if (payload.student_id) router.push(`/alunos/${payload.student_id}`);
      else router.push("/alunos");
    });
  }

  return (
    <form onSubmit={form.handleSubmit(submit)} className="space-y-8">
      <section className="grid gap-5 md:grid-cols-2">
        <FormField id="schoolId" label="Escola" required error={form.formState.errors.schoolId?.message}>
          <select id="schoolId" {...form.register("schoolId")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
            {schools.map((school) => <option key={school.id} value={school.id}>{school.name} · {school.code}</option>)}
          </select>
        </FormField>
        <FormField id="schoolNumber" label="Número do aluno" required error={form.formState.errors.schoolNumber?.message}>
          <Input id="schoolNumber" {...form.register("schoolNumber")} />
        </FormField>
      </section>

      <section className="space-y-5">
        <div><h2 className="text-base font-semibold">Identidade</h2><p className="text-sm text-muted-foreground">Dados nucleares do aluno. Campos adicionais podem ser completados depois.</p></div>
        <div className="grid gap-5 md:grid-cols-2">
          <FormField id="fullName" label="Nome completo" required error={form.formState.errors.fullName?.message}><Input id="fullName" {...form.register("fullName")} /></FormField>
          <FormField id="gender" label="Sexo"><select id="gender" {...form.register("gender")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Não indicado</option><option value="M">Masculino</option><option value="F">Feminino</option></select></FormField>
          <FormField id="firstName" label="Primeiro nome"><Input id="firstName" {...form.register("firstName")} /></FormField>
          <FormField id="lastName" label="Apelido"><Input id="lastName" {...form.register("lastName")} /></FormField>
          <FormField id="birthDate" label="Data de nascimento"><Input id="birthDate" type="date" {...form.register("birthDate")} /></FormField>
          <FormField id="nationalId" label="Documento de identificação"><Input id="nationalId" {...form.register("nationalId")} /></FormField>
        </div>
      </section>

      <section className="space-y-5">
        <div><h2 className="text-base font-semibold">Contacto e residência</h2><p className="text-sm text-muted-foreground">Informação usada pela secretaria para contacto e localização.</p></div>
        <div className="grid gap-5 md:grid-cols-2">
          <FormField id="phone" label="Telefone"><Input id="phone" {...form.register("phone")} /></FormField>
          <FormField id="email" label="Email" error={form.formState.errors.email?.message}><Input id="email" type="email" {...form.register("email")} /></FormField>
          <div className="md:col-span-2"><FormField id="address" label="Residência atual"><Textarea id="address" {...form.register("address")} /></FormField></div>
        </div>
      </section>

      <div className="flex justify-end gap-2 border-t border-border pt-5">
        <Button type="button" variant="outline" onClick={() => router.back()}>Cancelar</Button>
        <Button type="submit" disabled={pending}>{pending ? "A registar…" : "Registar aluno"}</Button>
      </div>
    </form>
  );
}
