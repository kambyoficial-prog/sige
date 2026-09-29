"use client";

import { Toaster as Sonner } from "sonner";

export function Toaster() {
  return (
    <Sonner
      position="bottom-right"
      closeButton
      richColors
      toastOptions={{
        classNames: {
          toast: "group border-border bg-background text-foreground shadow-lg",
          description: "text-muted-foreground",
        },
      }}
    />
  );
}
