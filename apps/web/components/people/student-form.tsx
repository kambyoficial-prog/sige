"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
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
  firstName: z.string().trim().min(2, "Indique o nome do aluno."),
  lastName: z.string().trim().optional(),
  gender: z.enum(["M", "F"]).optional(),
  birthDate: z.string().optional(),
  documentType: z.string().optional(),
  documentValue: z.string().trim().max(120).optional(),
  phone: z.string().trim().max(40).optional(),
  email: z.string().email("Email inválido.").or(z.literal("")),
  address: z.string().trim().max(240).optional(),
});

type FormValues = z.infer<typeof schema>;

const documentTypes = [
  ["BI", "Bilhete de Identidade"],
  ["BI_TALAO", "Talão de BI"],
  ["BIRTH_CERTIFICATE", "Certidão / assento de nascimento"],
  ["PERSONAL_ID", "Cédula pessoal"],
  ["PASSPORT", "Passaporte"],
  ["DIRE", "DIRE"],
  ["VOTER_CARD", "Cartão de eleitor"],
  ["OTHER", "Outro documento"],
] as const;

const steps = ["Identidade", "Identificação", "Contacto", "Confirmação"];

export function StudentForm({ schools }: { schools: Array<{ id: string; name: string; code: string }> }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState(0);
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { schoolId: schools[0]?.id ?? "", email: "", documentType: "" },
  });
  const values = form.watch();
  const fullName = [values.firstName, values.lastName].filter(Boolean).join(" ");

  function advance() {
    const fields =
      step === 0 ? ["firstName", "lastName", "gender", "birthDate"] :
      step === 1 ? ["documentType", "documentValue"] :
      step === 2 ? ["phone", "email", "address"] : [];
    if (!fields.length) return form.handleSubmit(submit)();
    form.trigger(fields as Array<keyof FormValues>).then((ok) => ok && setStep(step + 1));
  }

  function submit(values: FormValues) {
    startTransition(async () => {
      const result = await registerStudentAction(values);
      if (!result.ok) {
        toast.error(errorMessage(result.code as never));
        return;
      }
      const payload = result.result as { student_id?: string; school_number?: string };
      toast.success(payload.school_number ? `Aluno criado. Número: ${payload.school_number}.` : "Aluno criado.");
      if (payload.student_id) router.push(`/matriculas/nova?studentId=${payload.student_id}`);
      else router.push("/alunos");
    });
  }

  return (
    <form onSubmit={(e) => e.preventDefault()} className="space-y-8">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {steps.map((label, index) => (
          <button key={label} type="button" onClick={() => index < step && setStep(index)}
            className={`rounded-lg border p-3 text-left text-sm ${index === step ? "border-foreground bg-accent" : "border-border"}`}>
            <span className="font-medium">{index + 1}. {label}</span>
          </button>
        ))}
      </div>

      {step === 0 && <section className="space-y-5">
        <div><h2 className="font-semibold">Identidade</h2><p className="text-sm text-muted-foreground">O número do aluno não é digitado. O SIGE atribui-o automaticamente.</p></div>
        <div className="grid gap-5 md:grid-cols-2">
          <FormField id="firstName" label="Nome(s)" required error={form.formState.errors.firstName?.message}><Input id="firstName" autoFocus {...form.register("firstName")} placeholder="Nome próprio e nomes do meio" /></FormField>
          <FormField id="lastName" label="Apelido"><Input id="lastName" {...form.register("lastName")} /></FormField>
          <FormField id="gender" label="Sexo"><select id="gender" {...form.register("gender")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Não indicado</option><option value="M">Masculino</option><option value="F">Feminino</option></select></FormField>
          <FormField id="birthDate" label="Data de nascimento"><Input id="birthDate" type="date" {...form.register("birthDate")} /></FormField>
        </div>
        <div className="rounded-lg bg-muted/50 p-4 text-sm">Nome apresentado: <strong>{fullName || "—"}</strong></div>
      </section>}

      {step === 1 && <section className="space-y-5">
        <div><h2 className="font-semibold">Documento de identificação</h2><p className="text-sm text-muted-foreground">O tipo é separado do número. Alguns documentos podem não ter número.</p></div>
        <div className="grid gap-5 md:grid-cols-2">
          <FormField id="documentType" label="Tipo de documento"><select id="documentType" {...form.register("documentType")} className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="">Não apresentado</option>{documentTypes.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></FormField>
          <FormField id="documentValue" label="Número / referência"><Input id="documentValue" {...form.register("documentValue")} placeholder="Opcional quando não existir" /></FormField>
        </div>
      </section>}

      {step === 2 && <section className="space-y-5">
        <div><h2 className="font-semibold">Contacto e residência</h2><p className="text-sm text-muted-foreground">Email e telefone são opcionais.</p></div>
        <div className="grid gap-5 md:grid-cols-2">
          <FormField id="phone" label="Telefone"><Input id="phone" {...form.register("phone")} /></FormField>
          <FormField id="email" label="Email" error={form.formState.errors.email?.message}><Input id="email" type="email" {...form.register("email")} placeholder="Opcional" /></FormField>
          <div className="md:col-span-2"><FormField id="address" label="Residência atual"><Textarea id="address" {...form.register("address")} /></FormField></div>
        </div>
      </section>}

      {step === 3 && <section className="space-y-5">
        <div><h2 className="font-semibold">Confirmar registo</h2><p className="text-sm text-muted-foreground">Depois deste passo, o processo continua com encarregado, transporte, matrícula, turma e acesso.</p></div>
        <div className="grid gap-4 rounded-xl border border-border p-5 sm:grid-cols-2">
          <div><p className="text-xs text-muted-foreground">Escola</p><p className="font-medium">{schools[0]?.name ?? "—"}</p></div>
          <div><p className="text-xs text-muted-foreground">Nome</p><p className="font-medium">{fullName || "—"}</p></div>
          <div><p className="text-xs text-muted-foreground">Nascimento</p><p className="font-medium">{values.birthDate || "—"}</p></div>
          <div><p className="text-xs text-muted-foreground">Documento</p><p className="font-medium">{documentTypes.find(([v]) => v === values.documentType)?.[1] ?? "Não apresentado"}{values.documentValue ? ` · ${values.documentValue}` : ""}</p></div>
          <div><p className="text-xs text-muted-foreground">Telefone</p><p className="font-medium">{values.phone || "—"}</p></div>
          <div><p className="text-xs text-muted-foreground">Email</p><p className="font-medium">{values.email || "—"}</p></div>
          <div className="sm:col-span-2"><p className="text-xs text-muted-foreground">Residência</p><p className="font-medium">{values.address || "—"}</p></div>
        </div>
      </section>}

      <div className="flex justify-between border-t border-border pt-5">
        <Button type="button" variant="outline" onClick={() => step ? setStep(step - 1) : router.back()}>{step ? "Anterior" : "Cancelar"}</Button>
        <Button type="button" disabled={pending} onClick={advance}>{pending ? "A criar…" : step === 3 ? "Criar aluno e continuar" : "Continuar"}</Button>
      </div>
    </form>
  );
}
