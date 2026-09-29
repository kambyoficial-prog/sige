"use client";
import * as React from "react";
import { Button } from "@/components/ui/button";

export function ConfirmDialog({ open, title, description, confirmLabel = "Confirmar", destructive = false, busy = false, onConfirm, onCancel }: { open: boolean; title: string; description: string; confirmLabel?: string; destructive?: boolean; busy?: boolean; onConfirm: () => void; onCancel: () => void }) {
  const ref = React.useRef<HTMLDialogElement>(null);
  React.useEffect(() => { const el = ref.current; if (!el) return; if (open && !el.open) el.showModal(); if (!open && el.open) el.close(); }, [open]);
  return <dialog ref={ref} onCancel={onCancel} onClose={onCancel} className="w-[min(28rem,calc(100vw-2rem))] rounded-xl border border-border bg-background p-0 text-foreground shadow-2xl backdrop:bg-black/40"><div className="p-6"><h2 className="text-base font-semibold">{title}</h2><p className="mt-2 text-sm leading-6 text-muted-foreground">{description}</p><div className="mt-6 flex justify-end gap-2"><Button variant="outline" onClick={onCancel} disabled={busy}>Cancelar</Button><Button variant={destructive ? "destructive" : "default"} onClick={onConfirm} disabled={busy}>{busy ? "A processar…" : confirmLabel}</Button></div></div></dialog>;
}
