import { PageHeader } from "@/components/ui/page-header";
import { getAcademicYearOptions, getFinanceCharges } from "@/lib/sige/queries";

export default async function FinanceChargesPage() {
  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.status === "OPEN") ?? years[0];
  const rows = await getFinanceCharges(year?.id);

  return <div className="space-y-6">
    <PageHeader title="Propinas" description="Obrigações financeiras por aluno e ano letivo." />
    {!rows.length ? <div className="rounded-xl border p-8 text-sm text-muted-foreground">Ainda não existem obrigações financeiras para este contexto.</div> :
    <div className="overflow-x-auto rounded-xl border"><table className="w-full min-w-[900px] text-sm">
      <thead className="bg-muted/40"><tr className="border-b">
        <th className="px-4 py-3 text-left">Aluno</th><th className="px-4 py-3 text-left">Tipo</th><th className="px-4 py-3 text-left">Vencimento</th><th className="px-4 py-3 text-right">Valor</th><th className="px-4 py-3 text-right">Pago</th><th className="px-4 py-3 text-right">Saldo</th><th className="px-4 py-3 text-left">Estado</th>
      </tr></thead><tbody>{rows.map((r) => <tr key={String(r.id)} className="border-b last:border-0">
        <td className="px-4 py-3 font-medium">{String(r.student_name ?? "—")}</td><td className="px-4 py-3">{String(r.fee_type ?? r.description ?? "—")}</td><td className="px-4 py-3">{String(r.due_on ?? "—")}</td>
        <td className="px-4 py-3 text-right">{Number(r.effective_amount ?? r.amount ?? 0).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td>
        <td className="px-4 py-3 text-right">{Number(r.paid_amount ?? 0).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td>
        <td className="px-4 py-3 text-right">{(Number(r.effective_amount ?? r.amount ?? 0)-Number(r.paid_amount ?? 0)).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</td>
        <td className="px-4 py-3">{String(r.status ?? "—")}</td>
      </tr>)}</tbody>
    </table></div>}
  </div>;
}
