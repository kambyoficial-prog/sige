import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getFinancePaymentWorkbench } from "@/lib/sige/queries";
import { PrintButton } from "@/components/finance/print-button";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function PaymentReceiptPage({params}:{params:Promise<{id:string}>}){
 const {id}=await params;
 const rows=await getFinancePaymentWorkbench();
 const p=rows.find((row)=>String(row.id)===id) as any;
 const supabase=await createSupabaseServerClient();
 const receiptData=p?.receipt_id ? (await supabase.rpc("get_receipt_document",{p_receipt_id:String(p.receipt_id)})).data as any : null;
 const snapshot=receiptData?.receipt_snapshot as any;
 const document=snapshot??(p?{receipt_number:p.receipt_number,issued_at:null,student:{school_number:p.school_number,full_name:p.student_name},payment:{id:p.id,amount:p.amount,method:p.method,paid_at:p.paid_at,external_reference:p.external_reference},allocations:[]}:null);
 if(!p) return <div className="space-y-4"><PageHeader title="Pagamento não encontrado" description="O registo não está disponível para a sua área financeira."/><Link href="/financeiro/pagamentos" className={buttonVariants({variant:"outline"})}>Voltar aos pagamentos</Link></div>;
 return <div className="space-y-6">
  <div className="print:hidden"><PageHeader title={p.receipt_number ? "Recibo "+String(p.receipt_number) : "Pagamento"} description="Documento financeiro para conferência e impressão." actions={<PrintButton />}/></div>
  <article className="mx-auto max-w-2xl rounded-none border bg-white p-8 text-black shadow-sm print:border-0 print:shadow-none">
   <div className="border-b pb-5 text-center"><h1 className="text-2xl font-semibold">RECIBO DE PAGAMENTO</h1><p className="mt-1 text-sm">{String(document?.receipt_number??"Ainda não emitido")}</p></div>
   <div className="grid gap-4 py-6 sm:grid-cols-2 text-sm">
    <div><div className="text-xs text-gray-500">Aluno</div><div className="font-medium">{String(document?.student?.full_name??"—")}</div></div>
    <div><div className="text-xs text-gray-500">Número</div><div className="font-medium">{String(document?.student?.school_number??"—")}</div></div>
    <div><div className="text-xs text-gray-500">Data do pagamento</div><div>{String(document?.payment?.paid_at??"—")}</div></div>
    <div><div className="text-xs text-gray-500">Método</div><div>{String(document?.payment?.method??"—")}</div></div>
    <div><div className="text-xs text-gray-500">Referência</div><div>{String(document?.payment?.external_reference??"—")}</div></div>
    <div><div className="text-xs text-gray-500">Estado</div><div>{String(p.status??"—")}</div></div>
   </div>
   <div className="border-y py-5"><div className="flex justify-between text-lg font-semibold"><span>Total recebido</span><span>{Number(document?.payment?.amount??0).toLocaleString("pt-MZ",{minimumFractionDigits:2})} MT</span></div></div>
   <p className="pt-6 text-xs text-gray-500">Documento emitido pelo SIGE. A validação física, assinatura ou carimbo seguem o procedimento definido pela escola.</p>
   <div className="mt-12 grid grid-cols-2 gap-12 text-center text-xs"><div className="border-t pt-2">Secretaria</div><div className="border-t pt-2">Assinatura / carimbo</div></div>
  </article>
  <div className="print:hidden"><Link href="/financeiro/pagamentos" className={buttonVariants({variant:"outline"})}>Voltar</Link></div>
  <style>{'@media print { @page { margin: 12mm; } body { background: white !important; } }'}</style>
 </div>;
}
