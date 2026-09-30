import { PageHeader } from "@/components/ui/page-header";
import { getStudentFinancialPortal } from "@/lib/sige/student-financial";

const money = (value: number) =>
  value.toLocaleString("pt-MZ", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " MT";

const statusLabel: Record<string, string> = {
  OPEN: "Por pagar",
  PARTIALLY_PAID: "Parcial",
  PAID: "Pago",
  OVERDUE: "Em atraso",
  PENDING: "Em verificação",
  CONFIRMED: "Confirmado",
  REVERSED: "Estornado",
};

export default async function StudentPaymentsPage() {
  const portal = await getStudentFinancialPortal();
  const charges = portal.charges ?? [];
  const instructions = portal.payment_instructions ?? [];
  const payments = portal.payments ?? [];
  const outstanding = charges.reduce((sum, c) => sum + Number(c.remaining_amount ?? 0), 0);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Meus pagamentos"
        description={portal.academic_year ? portal.academic_year.label : "Situação financeira do ano letivo atual."}
      />

      <section className="grid gap-4 md:grid-cols-3">
        <div className="rounded-2xl border p-5"><p className="text-sm text-muted-foreground">Em aberto</p><p className="mt-2 text-2xl font-semibold">{money(outstanding)}</p></div>
        <div className="rounded-2xl border p-5"><p className="text-sm text-muted-foreground">Cobranças</p><p className="mt-2 text-2xl font-semibold">{charges.length}</p></div>
        <div className="rounded-2xl border p-5"><p className="text-sm text-muted-foreground">Pagamentos registados</p><p className="mt-2 text-2xl font-semibold">{payments.length}</p></div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Meses e obrigações</h2>
        {!charges.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">A escola ainda não publicou cobranças para este ano letivo.</div> :
          <div className="overflow-x-auto rounded-xl border"><table className="w-full min-w-[760px] text-sm">
            <thead className="bg-muted/40"><tr className="border-b"><th className="px-4 py-3 text-left">Período</th><th className="px-4 py-3 text-left">Vencimento</th><th className="px-4 py-3 text-right">Valor</th><th className="px-4 py-3 text-right">Pago</th><th className="px-4 py-3 text-right">Saldo</th><th className="px-4 py-3 text-left">Estado</th></tr></thead>
            <tbody>{charges.map(c => <tr key={c.id} className="border-b last:border-0">
              <td className="px-4 py-3 font-medium">{c.fee_type ?? c.description ?? "Obrigação"}</td>
              <td className="px-4 py-3">{c.due_on}</td>
              <td className="px-4 py-3 text-right">{money(Number(c.amount))}</td>
              <td className="px-4 py-3 text-right">{money(Number(c.paid_amount))}</td>
              <td className="px-4 py-3 text-right">{money(Number(c.remaining_amount))}</td>
              <td className="px-4 py-3">{statusLabel[c.status] ?? c.status}</td>
            </tr>)}</tbody>
          </table></div>}
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Dados para pagamento</h2>
        {!instructions.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">A escola ainda não configurou os dados bancários.</div> :
          <div className="grid gap-4 md:grid-cols-2">{instructions.map(i => <div key={i.id} className="rounded-2xl border p-5 space-y-2">
            <h3 className="font-medium">{i.label}</h3>
            {i.bank_name && <p><span className="text-muted-foreground">Banco:</span> {i.bank_name}</p>}
            {i.account_name && <p><span className="text-muted-foreground">Titular:</span> {i.account_name}</p>}
            {i.account_number && <p><span className="text-muted-foreground">Conta:</span> {i.account_number}</p>}
            {i.nib && <p><span className="text-muted-foreground">NIB:</span> {i.nib}</p>}
            {i.iban && <p><span className="text-muted-foreground">IBAN:</span> {i.iban}</p>}
            {i.branch && <p><span className="text-muted-foreground">Agência:</span> {i.branch}</p>}
            {i.payment_reference_template && <p><span className="text-muted-foreground">Referência:</span> {i.payment_reference_template}</p>}
            {i.instructions && <p className="pt-2 text-sm text-muted-foreground">{i.instructions}</p>}
          </div>)}</div>}
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Histórico</h2>
        {!payments.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">Ainda não existem pagamentos registados.</div> :
          <div className="overflow-x-auto rounded-xl border"><table className="w-full min-w-[700px] text-sm">
            <thead className="bg-muted/40"><tr className="border-b"><th className="px-4 py-3 text-left">Data</th><th className="px-4 py-3 text-right">Valor</th><th className="px-4 py-3 text-left">Método</th><th className="px-4 py-3 text-left">Estado</th><th className="px-4 py-3 text-left">Recibo</th></tr></thead>
            <tbody>{payments.map(p => <tr key={p.id} className="border-b last:border-0"><td className="px-4 py-3">{p.paid_at}</td><td className="px-4 py-3 text-right">{money(Number(p.amount))}</td><td className="px-4 py-3">{p.method}</td><td className="px-4 py-3">{statusLabel[p.status] ?? p.status}</td><td className="px-4 py-3">{p.receipt_number ?? "—"}</td></tr>)}</tbody>
          </table></div>}
      </section>
    </div>
  );
}
