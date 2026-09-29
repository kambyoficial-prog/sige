import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export default function AccessDeniedPage() {
  return <main className="grid min-h-svh place-items-center bg-background px-6"><section className="max-w-md text-center"><p className="text-sm text-muted-foreground">Acesso</p><h1 className="mt-2 text-2xl font-semibold tracking-tight">A conta não tem acesso ao SIGE.</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">A sua conta autenticou-se, mas não existe uma associação ativa a uma escola.</p><Link href="/login" className={cn(buttonVariants({variant:"outline",className:"mt-6"}))}>Voltar ao início de sessão</Link></section></main>;
}
