import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { getStudentDirectory } from "@/lib/sige/queries";
import { recordPaymentAction } from "@/lib/sige/finance-actions";

async function submitPayment(formData: FormData) {
  "use server";
  await recordPaymentAction({
    studentId: String(formData.get("studentId")),
    amount: Number(formData.get("amount")),
    method: String(formData.get("method")),
    paidAt: new Date(String(formData.get("paidAt")) + "T12:00:00+02:00").toISOString(),
    externalReference: String(formData.get("externalReference") || "") || undefined,
    notes: String(formData.get("notes") || "") || undefined,
  });
  revalidatePath("/financeiro/pagamentos");
  revalidatePath("/financeiro/saldos");
  revalidatePath("/financeiro/propinas");
  redirect("/financeiro/pagamentos");
}

export default async function NewPaymentPage() {
  const students = await getStudentDirectory();

  return (
    <div className="space-y-6">
      <PageHeader title="Novo pagamento" description="Registar um pagamento recebido pela escola. A confirmação e a alocação permanecem etapas explícitas do ciclo financeiro." />
      <form action={submitPayment} className="max-w-2xl space-y-5 rounded-xl border border-border bg-card p-6">
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Aluno</span>
          <select name="studentId" required className="h-10 w-full rounded-md border bg-background px-3">
            {students.map((student) => <option key={student.id} value={student.id}>{student.school_number} · {student.full_name}</option>)}
          </select>
        </label>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="block space-y-1.5 text-sm">
            <span className="font-medium">Valor (MT)</span>
            <input name="amount" type="number" min="0.01" step="0.01" required className="h-10 w-full rounded-md border bg-background px-3" />
          </label>
          <label className="block space-y-1.5 text-sm">
            <span className="font-medium">Data</span>
            <input name="paidAt" type="date" required defaultValue={new Date().toISOString().slice(0,10)} className="h-10 w-full rounded-md border bg-background px-3" />
          </label>
        </div>
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Método</span>
          <select name="method" defaultValue="CASH" className="h-10 w-full rounded-md border bg-background px-3">
            <option value="CASH">Numerário</option>
            <option value="BANK_TRANSFER">Transferência bancária</option>
            <option value="MOBILE_MONEY">Mobile money</option>
            <option value="CARD">Cartão</option>
            <option value="OTHER">Outro</option>
          </select>
        </label>
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Referência externa (opcional)</span>
          <input name="externalReference" maxLength={200} className="h-10 w-full rounded-md border bg-background px-3" />
        </label>
        <label className="block space-y-1.5 text-sm">
          <span className="font-medium">Observação (opcional)</span>
          <textarea name="notes" maxLength={1000} className="min-h-24 w-full rounded-md border bg-background px-3 py-2" />
        </label>
        <div className="rounded-lg border bg-muted/30 p-3 text-sm text-muted-foreground">
          Registar o pagamento não altera automaticamente o saldo. O fluxo financeiro mantém confirmação e alocação como operações separadas.
        </div>
        <div className="flex justify-end"><Button type="submit">Registar pagamento</Button></div>
      </form>
    </div>
  );
}
