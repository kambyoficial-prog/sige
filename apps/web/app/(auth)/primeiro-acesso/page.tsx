import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { FirstAccessForm } from "@/components/auth/first-access-form";

export default async function FirstAccessPage() {
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getUser();
  if (!data.user) redirect("/login");

  return (
    <main className="min-h-svh bg-background px-6 py-10 text-foreground">
      <div className="mx-auto flex min-h-[calc(100svh-5rem)] max-w-md flex-col justify-center">
        <div className="mb-10">
          <p className="text-sm font-semibold tracking-tight">SIGE</p>
          <h1 className="mt-8 text-3xl font-semibold tracking-tight">Primeiro acesso</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            Defina uma palavra-passe pessoal antes de continuar.
          </p>
        </div>
        <FirstAccessForm />
      </div>
    </main>
  );
}
