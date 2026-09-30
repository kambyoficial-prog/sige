import Link from "next/link";
import { revalidatePath } from "next/cache";
import { PageHeader } from "@/components/ui/page-header";
import { buttonVariants } from "@/components/ui/button";
import { getFinancePaymentWorkbench } from "@/lib/sige/queries";
import { confirmPaymentAction, allocatePaymentAction, issueReceiptAction } from "@/lib/sige/finance-actions";

const money=(v:number)=>v.toLocaleString("pt-MZ",{minimumFractionDigits:2,maximumFractionDigits:2})+" MT";
const labels:Record<string,string>={PENDING:"Pendente",CONFIRMED:"Confirmado",REVERSED:"Estornado"};

async function confirm(formData:FormData){ "use server"; await confirmPaymentAction({paymentId:String(formData.get("paymentId"))}); revalidatePath("/financeiro/pagamentos"); }
async function allocate(formData:FormData){ "use server"; await allocatePaymentAction({paymentId:String(formData.get("paymentId")),chargeId:String(formData.get("chargeId")),amount:Number(formData.get("amount"))}); revalidatePath("/financeiro/pagamentos"); }
async function receipt(formData:FormData){ "use server"; await issueReceiptAction({paymentId:String(formData.get("paymentId")),receiptNumber:"AUTO"}); revalidatePath("/financeiro/pagamentos"); }

export default async function FinancePaymentsPage(){
 const rows=await getFinancePaymentWorkbench();
 return <div className="space-y-6">
  <PageHeader title="Pagamentos" description="Receção, verificação, alocação e emissão de recibos." actions={<Link href="/financeiro/pagamentos/novo" className={buttonVariants()}>Novo pagamento</Link>}/>
  <div className="rounded-xl border bg-card">
   <div className="border-b px-5 py-4"><h2 className="font-semibold">Fila operacional</h2><p className="text-sm text-muted-foreground">Os pagamentos permanecem pendentes até a Secretaria verificar o comprovativo.</p></div>
   {!rows.length?<div className="p-8 text-sm text-muted-foreground">Ainda não existem pagamentos registados.</div>:
   <div className="divide-y">{rows.map((r:any)=><article key={String(r.id)} className="p-5 space-y-4">
    <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
      <div><div className="font-semibold">{String(r.student_name??"—")}</div><div className="text-sm text-muted-foreground">{String(r.school_number??"")} · {String(r.paid_at??"—")}</div></div>
      <div className="text-left md:text-right"><div className="text-lg font-semibold">{money(Number(r.amount??0))}</div><div className="text-sm">{labels[String(r.status)]??String(r.status)}</div></div>
    </div>
    <div className="grid gap-3 text-sm md:grid-cols-4">
      <div><span className="text-muted-foreground">Método</span><div>{String(r.method??"—")}</div></div>
      <div><span className="text-muted-foreground">Referência</span><div>{String(r.external_reference??"—")}</div></div>
      <div><span className="text-muted-foreground">Alocado</span><div>{money(Number(r.allocated_amount??0))}</div></div>
      <div><span className="text-muted-foreground">Por alocar</span><div>{money(Number(r.unallocated_amount??0))}</div></div>
    </div>
    {r.notes&&<div className="rounded-lg bg-muted/40 p-3 text-sm">{String(r.notes)}</div>}
    <div className="flex flex-wrap gap-2">
      {r.status==="PENDING"&&<form action={confirm}><input type="hidden" name="paymentId" value={String(r.id)}/><button className={buttonVariants({size:"sm"})}>Confirmar pagamento</button></form>}
      {r.status==="CONFIRMED"&&Number(r.unallocated_amount)>0&&Array.isArray(r.charges)&&r.charges.length>0&&
        (r.charges as any[]).map((c:any)=><form key={String(c.id)} action={allocate} className="flex items-center gap-1">
          <input type="hidden" name="paymentId" value={String(r.id)}/><input type="hidden" name="chargeId" value={String(c.id)}/>
          <input type="hidden" name="amount" value={String(Math.min(Number(r.unallocated_amount),Number(c.remaining_amount)))} />
          <button className={buttonVariants({size:"sm",variant:"outline"})}>Alocar {String(c.description??"cobrança")} · {money(Math.min(Number(r.unallocated_amount),Number(c.remaining_amount)))}</button>
        </form>)}
      {r.status==="CONFIRMED"&&Number(r.unallocated_amount)===0&&!r.receipt_number&&<form action={receipt}><input type="hidden" name="paymentId" value={String(r.id)}/><button className={buttonVariants({size:"sm"})}>Emitir recibo</button></form>}
      {r.receipt_number&&<Link href={"/financeiro/pagamentos/"+String(r.id)} className={buttonVariants({size:"sm",variant:"outline"})}>Ver / imprimir recibo</Link>}
    </div>
   </article>)}</div>}
  </div>
 </div>;
}
