"use client";

import { Search, X } from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import * as React from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

export function SearchInput({ param = "q", placeholder = "Pesquisar…" }: { param?: string; placeholder?: string }) {
  const router = useRouter();
  const params = useSearchParams();
  const [value, setValue] = React.useState(params.get(param) ?? "");
  React.useEffect(() => setValue(params.get(param) ?? ""), [params, param]);
  function apply(next: string) { const p = new URLSearchParams(params.toString()); if (next.trim()) p.set(param, next.trim()); else p.delete(param); p.delete("page"); router.replace(`?${p.toString()}`); }
  return <div className="relative max-w-sm"><Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" /><Input value={value} onChange={e => setValue(e.target.value)} onKeyDown={e => { if (e.key === "Enter") apply(value); }} placeholder={placeholder} className="pl-9 pr-9" aria-label={placeholder} />{value ? <Button type="button" variant="ghost" size="icon" className="absolute right-1 top-1 size-8" aria-label="Limpar pesquisa" onClick={() => { setValue(""); apply(""); }}><X size={15} aria-hidden="true" /></Button> : null}</div>;
}
