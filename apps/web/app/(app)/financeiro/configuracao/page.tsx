import { revalidatePath } from "next/cache";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createFeeTypeAction, createFeePlanAction, addFeePlanItemAction } from "@/lib/sige/fee-actions";
import { getAcademicYearOptions } from "@/lib/sige/queries";

async function feeType(formData: FormData) {
  "use server";
  await createFeeTypeAction({ schoolId:String(formData.get("schoolId")), code:String(formData.get("code")), name:String(formData.get("name")) });
  revalidatePath("/financeiro/configuracao");
}
async function feePlan(formData: FormData) {
  "use server";
  await createFeePlanAction({ schoolId:String(formData.get("schoolId")), academicYearId:String(formData.get("academicYearId")), code:String(formData.get("code")), name:String(formData.get("name")) });
  revalidatePath("/financeiro/configuracao");
}
async function feeItem(formData: FormData) {
  "use server";
  await addFeePlanItemAction({
    feePlanId:String(formData.get("feePlanId")), feeTypeId:String(formData.get("feeTypeId")),
    amount:Number(formData.get("amount")), dueDay:formData.get("dueDay")?Number(formData.get("dueDay")):undefined,
    sequenceNo:formData.get("sequenceNo")?Number(formData.get("sequenceNo")):undefined,
  });
  revalidatePath("/financeiro/configuracao");
}

export default async function FinanceConfigurationPage() {
  const access=await getCurrentAccessContext();
  const membership=access.memberships[0];
  const schoolId=membership?.school_id;
  if(!schoolId) return <div className="rounded-xl border p-8 text-sm text-muted-foreground">Sem associação escolar ativa.</div>;
  const supabase=await createSupabaseServerClient();
  const [types,plans,years]=await Promise.all([
    supabase.from("fee_types").select("id,code,name,active").eq("school_id",schoolId).order("code"),
    supabase.from("fee_plans").select("id,code,name,academic_year_id,active").eq("school_id",schoolId).order("created_at",{ascending:false}),
    getAcademicYearOptions(),
  ]);
  const canManage=membership.permissions.includes("finance.manage");
  return <div className="space-y-8">
    <PageHeader title="Configuração financeira" description="A escola define tipos de cobrança, planos e valores. O SIGE não inventa montantes." />
    {!canManage?<div className="rounded-lg border bg-muted/30 p-4 text-sm">Esta área é somente leitura para o seu perfil.</div>:null}
    <section className="grid gap-6 lg:grid-cols-2">
      <form action={feeType} className="space-y-4 rounded-xl border p-5">
        <h2 className="font-semibold">Tipo de cobrança</h2>
        <input type="hidden" name="schoolId" value={schoolId}/>
        <input name="code" required placeholder="MENSALIDADE" className="h-10 w-full rounded-md border bg-background px-3 text-sm"/>
        <input name="name" required placeholder="Mensalidade" className="h-10 w-full rounded-md border bg-background px-3 text-sm"/>
        <Button disabled={!canManage}>Criar tipo</Button>
      </form>
      <form action={feePlan} className="space-y-4 rounded-xl border p-5">
        <h2 className="font-semibold">Plano do ano lectivo</h2>
        <input type="hidden" name="schoolId" value={schoolId}/>
        <select name="academicYearId" required className="h-10 w-full rounded-md border bg-background px-3">{years.map(y=><option key={y.id} value={y.id}>{y.label}</option>)}</select>
        <input name="code" required placeholder="PLANO-2026-27" className="h-10 w-full rounded-md border bg-background px-3 text-sm"/>
        <input name="name" required placeholder="Plano 2026/2027" className="h-10 w-full rounded-md border bg-background px-3 text-sm"/>
        <Button disabled={!canManage}>Criar plano</Button>
      </form>
    </section>
    <section className="rounded-xl border p-5 space-y-5">
      <div><h2 className="font-semibold">Itens do plano</h2><p className="text-sm text-muted-foreground">Aqui a escola define o valor e, quando aplicável, o dia de vencimento.</p></div>
      <form action={feeItem} className="grid gap-3 md:grid-cols-5">
        <select name="feePlanId" required className="h-10 rounded-md border bg-background px-3">{(plans.data??[]).map(p=><option key={p.id} value={p.id}>{p.code} · {p.name}</option>)}</select>
        <select name="feeTypeId" required className="h-10 rounded-md border bg-background px-3">{(types.data??[]).map(t=><option key={t.id} value={t.id}>{t.code} · {t.name}</option>)}</select>
        <input name="amount" type="number" min="0.01" step="0.01" required placeholder="Valor MT" className="h-10 rounded-md border bg-background px-3"/>
        <input name="dueDay" type="number" min="1" max="31" placeholder="Dia venc." className="h-10 rounded-md border bg-background px-3"/>
        <Button disabled={!canManage}>Adicionar</Button>
      </form>
      <div className="grid gap-2">{(plans.data??[]).map(p=><div key={p.id} className="rounded-lg border p-3 text-sm"><strong>{p.code}</strong> · {p.name}</div>)}</div>
    </section>
  </div>;
}
