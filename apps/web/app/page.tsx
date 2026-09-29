import { ThemeToggle } from "@/components/theme-toggle";
export default function Home() {
  return (
    <main className="min-h-svh bg-background px-6 py-8 text-foreground sm:px-10 lg:px-16">
      <div className="mx-auto flex min-h-[calc(100svh-4rem)] max-w-6xl flex-col">
        <header className="flex items-center justify-between border-b border-border pb-5">
          <div>
            <p className="text-sm font-semibold tracking-tight">SIGE</p>
            <p className="mt-0.5 text-xs text-muted-foreground">Sistema Integrado de Gestão Escolar</p>
          </div>
          <ThemeToggle />
        </header>

        <section className="flex flex-1 items-center py-16 lg:py-24">
          <div className="max-w-2xl">
            <p className="mb-4 text-sm font-medium text-muted-foreground">Fundação da aplicação</p>
            <h1 className="text-4xl font-semibold tracking-[-0.035em] sm:text-5xl lg:text-6xl">
              Gestão escolar construída à volta do trabalho real.
            </h1>
            <p className="mt-6 max-w-xl text-base leading-7 text-muted-foreground sm:text-lg">
              A interface operacional do SIGE está a ser construída sobre os contratos académicos,
              financeiros e de autorização já definidos no backend.
            </p>
            <p className="mt-5 text-xs text-muted-foreground">
              O acesso será ligado à autenticação real na fase F1. Esta página não utiliza dados fictícios.
            </p>
          </div>
        </section>

        <footer className="border-t border-border pt-5 text-xs text-muted-foreground">
          Ensino Secundário · Fundação frontend F0
        </footer>
      </div>
    </main>
  );
}
