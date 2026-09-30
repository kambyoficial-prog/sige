"use client";

import { Button, buttonVariants } from "@/components/ui/button";

export function PrintButton() {
  return <Button type="button" variant="outline" onClick={() => window.print()}>
    Imprimir
  </Button>;
}
