import { PageHeader } from "@/components/ui/page-header";
import { getAcademicYearOptions, getFinancialBalances } from "@/lib/sige/queries";

export default async function FinanceBalancesPage() {
  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.status === "OPEN") ?? years[0];
  const rows = await getFinancialBalances(year?.id);
  return <div className="space-y-6">
    <PageHeader title="Saldos" description="Posição financeira derivada das obrigações e pagamentos confirmados." />
    {!rows.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">Ainda não existem saldos para este ano letivo.</div> :
    <div className="overflow-x-auto rounded-xl border"><table className="w-full min-w-[850px] text-sm">
      <thead className="bg-muted/40"><tr className="border-b"><th className="px-4 py-3 text-left">Aluno</th><th className="px-4 py-3 text-right">Faturado</th><th className="px-4 py-3 text-right">Pago</th><th className="px-4 py-3 text-right">Saldo</th></tr></thead>
      <tbody>{rows.map((r)=><tr key={String(r.student_name ?? r.student_id)} className="border-b last:border-0"><td className="px-4 py-3 font-medium">{String(r.student_id)}</td><td className="px-4 py-3 text-right">{Number(r.charged_amount).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td><td className="px-4 py-3 text-right">{Number(r.paid_amount).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td><td className="px-4 py-3 text-right">{Number(r.balance_amount).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td></tr>)}</tbody>
    </table></div>}
  </div>;
}
