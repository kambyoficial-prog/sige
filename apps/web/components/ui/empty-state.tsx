import { cn } from "@/lib/utils";

export function EmptyState({ title, description, action, className }: { title: string; description: string; action?: React.ReactNode; className?: string }) {
  return <div className={cn("flex min-h-48 flex-col items-center justify-center rounded-lg border border-dashed border-border px-6 py-10 text-center", className)}><h2 className="text-sm font-medium">{title}</h2><p className="mt-1 max-w-md text-sm leading-6 text-muted-foreground">{description}</p>{action ? <div className="mt-5">{action}</div> : null}</div>;
}
