import type { ReactNode } from "react";
import { Label } from "@/components/ui/label";

export function FormField({ id, label, description, error, required, children }: { id: string; label: string; description?: string; error?: string; required?: boolean; children: ReactNode }) {
  return <div className="space-y-2"><Label htmlFor={id}>{label}{required ? <span className="ml-1 text-destructive" aria-hidden="true">*</span> : null}</Label>{children}{description && !error ? <p id={`${id}-description`} className="text-xs leading-5 text-muted-foreground">{description}</p> : null}{error ? <p id={`${id}-error`} className="text-xs text-destructive" role="alert">{error}</p> : null}</div>;
}
