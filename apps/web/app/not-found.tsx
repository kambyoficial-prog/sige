import Link from "next/link";

import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export default function NotFound() {
  return (
    <main className="grid min-h-svh place-items-center bg-background px-6 text-foreground">
      <section className="w-full max-w-md text-center">
        <p className="text-sm font-medium text-muted-foreground">404</p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight">Página não encontrada.</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          O endereço solicitado não corresponde a uma operação disponível no SIGE.
        </p>
        <Link className={cn(buttonVariants({ className: "mt-6" }))} href="/">Voltar ao início</Link>
      </section>
    </main>
  );
}
