import { PageHeader } from "@/components/ui/page-header";
import { getCurrentAccessContext } from "@/lib/sige/access";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { buttonVariants } from "@/components/ui/button";
import Link from "next/link";

export default async function RegistrationsPage() {
  const access = await getCurrentAccessContext();
  const school = access.memberships.find((m) => m.permissions.includes("enrollment.read"));
  if (!school) return null;

  const supabase = await createSupabaseServerClient();
  const { data: rows, error } = await supabase
    .from("registration_directory")
    .select("*")
    .order("registered_on", { ascending: false });

  if (error) {
    console.error("[SIGE] registrations_directory failed", {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint,
    });
  }

  const canManage = school.permissions.includes("enrollment.manage");

  return (
    <div className="space-y-6">
      <PageHeader
        title="Inscrições"
        description="Inscrição anual, renovação e outros atos de frequência."
        actions={
          canManage ? (
            <Link href="/inscricoes/nova" className={buttonVariants()}>
              Nova inscrição
            </Link>
          ) : null
        }
      />

      {error ? (
        <section className="rounded-xl border border-destructive/20 bg-destructive/5 p-6">
          <h2 className="font-semibold">Não foi possível carregar as inscrições</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            O serviço de inscrições respondeu com um erro. Tente actualizar a página; se persistir, o detalhe técnico fica registado no servidor.
          </p>
        </section>
      ) : (
        <div className="overflow-hidden rounded-xl border border-border bg-card">
          <table className="w-full text-sm">
            <thead className="border-b bg-muted/40">
              <tr>
                <th className="p-4 text-left">Aluno</th>
                <th className="p-4 text-left">Ano</th>
                <th className="p-4 text-left">Classe</th>
                <th className="p-4 text-left">Tipo</th>
                <th className="p-4 text-left">Data</th>
                <th className="p-4 text-left">Estado</th>
              </tr>
            </thead>
            <tbody>
              {(rows ?? []).map((r) => (
                <tr key={r.id} className="border-b last:border-0">
                  <td className="p-4">
                    <div className="font-medium">{r.student_name}</div>
                    <div className="text-xs text-muted-foreground">{r.school_number}</div>
                  </td>
                  <td className="p-4">{r.academic_year}</td>
                  <td className="p-4">{r.grade_name}</td>
                  <td className="p-4">{r.registration_type}</td>
                  <td className="p-4">{r.registered_on}</td>
                  <td className="p-4">{r.status}</td>
                </tr>
              ))}
              {!rows?.length ? (
                <tr>
                  <td colSpan={6} className="p-10 text-center text-muted-foreground">
                    Ainda não existem inscrições.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}