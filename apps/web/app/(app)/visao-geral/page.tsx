import { PageHeader } from "@/components/ui/page-header";

export default function OverviewPage() {
  return <div className="space-y-6"><PageHeader title="Visão geral" description="O ponto de entrada operacional do SIGE. Os dados desta área serão ligados às consultas reais por fase." /><div className="rounded-lg border border-border bg-card p-6"><p className="text-sm font-medium">Contexto da escola</p><p className="mt-1 text-sm text-muted-foreground">A sua identidade e permissões já são resolvidas no servidor. Os módulos serão apresentados conforme o acesso atribuído.</p></div></div>;
}
