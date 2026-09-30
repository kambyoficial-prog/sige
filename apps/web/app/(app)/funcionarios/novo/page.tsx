import Link from "next/link";
import { redirect } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { PageHeader } from "@/components/sige/page-header";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SecretariatStaffForm } from "@/components/staff/secretariat-staff-form";
export default async function NewStaffPage(){const access=await getCurrentAccessContext();const school=access.memberships.find(m=>m.permissions.includes("staff.manage"));if(!school)redirect("/acesso-negado");const supabase=await createSupabaseServerClient();const{data:people}=await supabase.from("people").select("id").limit(1);void people;return <div className="space-y-6"><PageHeader title="Novo funcionário" description="Registar um funcionário da secretaria e emitir o primeiro acesso."/><div className="rounded-xl border border-border bg-card p-6"><SecretariatStaffForm schoolId={school.school_id}/></div><Link href="/funcionarios" className={buttonVariants({variant:"outline"})}>Cancelar</Link></div>}
