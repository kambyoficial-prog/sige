"use client";

import { Button } from "@/components/ui/button";

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="grid min-h-svh place-items-center bg-background px-6 text-foreground">
      <section className="w-full max-w-md text-center">
        <p className="text-sm font-medium text-muted-foreground">Erro inesperado</p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight">Não foi possível concluir esta operação.</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          Tente novamente. Se o problema persistir, o erro deverá ser tratado com a referência de diagnóstico disponível no ambiente.
        </p>
        <Button className="mt-6" onClick={() => reset()}>Tentar novamente</Button>
      </section>
    </main>
  );
}
