"use client";

import * as React from "react";
import { Copy, KeyRound, Loader2, Printer } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { activateStudentAccessAction } from "@/lib/sige/student-access-actions";

export function StudentAccessCard({ schoolId, studentId, schoolNumber, academicYearLabel }: { schoolId: string; studentId: string; schoolNumber: string; academicYearLabel: string | null }) {
  const [pending, setPending] = React.useState(false);
  const [credential, setCredential] = React.useState<string | null>(null);

  async function activate() {
    setPending(true);
    try {
      const result = await activateStudentAccessAction({ schoolId, studentId });
      if (!result.ok) {
        toast.error("Não foi possível activar o acesso.", { description: result.code });
        return;
      }
      setCredential(result.result.temporaryPassword);
      toast.success("Acesso do aluno activado.");
    } finally {
      setPending(false);
    }
  }

  async function copyCredential() {
    if (!credential) return;
    await navigator.clipboard.writeText(credential);
    toast.success("Credencial copiada.");
  }

  if (credential) {
    return (
      <div className="rounded-xl border border-border bg-card p-6 space-y-4">
        <div>
          <div className="flex items-center gap-2 font-semibold"><KeyRound size={17} aria-hidden="true" /> Acesso criado</div>
          <p className="mt-1 text-sm text-muted-foreground">Credencial inicial para entrega ao aluno. A senha pode ser alterada pelo próprio aluno depois do acesso.</p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-lg border border-border p-4"><p className="text-xs text-muted-foreground">Código</p><p className="mt-1 font-mono font-medium">{schoolNumber}.{academicYearLabel?.match(/\\d{4}/)?.[0] ?? new Date().getFullYear()}</p></div>
          <div className="rounded-lg border border-border p-4"><p className="text-xs text-muted-foreground">Palavra-passe temporária</p><p className="mt-1 font-mono font-medium break-all">{credential}</p></div>
        </div>
        <div className="flex flex-wrap gap-2"><Button variant="outline" onClick={copyCredential}><Copy size={15} aria-hidden="true" /> Copiar senha</Button><Button variant="outline" onClick={() => window.print()}><Printer size={15} aria-hidden="true" /> Imprimir folha</Button></div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="font-semibold">Acesso ao portal</h2>
          <p className="mt-1 text-sm text-muted-foreground">O aluno entra com o número escolar. Não é necessário criar um e-mail institucional.</p>
        </div>
        <Button onClick={activate} disabled={pending}>
          {pending ? <Loader2 className="animate-spin" aria-hidden="true" /> : <KeyRound size={15} aria-hidden="true" />}
          {pending ? "A activar…" : "Activar acesso"}
        </Button>
      </div>
    </div>
  );
}
