import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getFinancePayments } from "@/lib/sige/queries";

export default async function FinancePaymentsPage() {
  const rows = await getFinancePayments();
  return <div className="space-y-6">
    <PageHeader title="Pagamentos" description="Registo e histórico dos pagamentos financeiros." actions={<Link href="/financeiro/pagamentos/novo" className={buttonVariants()}>Novo pagamento</Link>} />
    {!rows.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">Ainda não existem pagamentos registados.</div> :
    <div className="overflow-x-auto rounded-xl border"><table className="w-full min-w-[850px] text-sm">
      <thead className="bg-muted/40"><tr className="border-b"><th className="px-4 py-3 text-left">Aluno</th><th className="px-4 py-3 text-left">Data</th><th className="px-4 py-3 text-left">Método</th><th className="px-4 py-3 text-right">Valor</th><th className="px-4 py-3 text-left">Estado</th><th className="px-4 py-3 text-left">Recibo</th></tr></thead>
      <tbody>{rows.map((r)=><tr key={String(r.id)} className="border-b last:border-0"><td className="px-4 py-3 font-medium">{String(r.student_name ?? "—")}</td><td className="px-4 py-3">{String(r.paid_at ?? "—")}</td><td className="px-4 py-3">{String(r.method ?? "—")}</td><td className="px-4 py-3 text-right">{Number(r.amount ?? 0).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td><td className="px-4 py-3">{String(r.status ?? "—")}</td><td className="px-4 py-3">{String(r.receipt_number ?? "—")}</td></tr>)}</tbody>
    </table></div>}
  </div>;
}
