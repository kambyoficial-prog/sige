import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function Pagination({
  page,
  totalPages,
  className,
}: {
  page: number;
  totalPages: number;
  className?: string;
}) {
  if (totalPages <= 1) return null;

  const href = (next: number) => {
    const params = new URLSearchParams(
      typeof window === "undefined" ? "" : window.location.search,
    );
    params.set("page", String(next));
    return `?${params.toString()}`;
  };

  return (
    <nav aria-label="Paginação" className={cn("flex items-center justify-between gap-3", className)}>
      <p className="text-xs text-muted-foreground">Página {page} de {totalPages}</p>
      <div className="flex gap-2">
        <Link href={href(Math.max(1, page - 1))} aria-disabled={page === 1}
          className={cn(buttonVariants({ variant: "outline", size: "sm" }), page === 1 && "pointer-events-none opacity-50")}>
          Anterior
        </Link>
        <Link href={href(Math.min(totalPages, page + 1))} aria-disabled={page === totalPages}
          className={cn(buttonVariants({ variant: "outline", size: "sm" }), page === totalPages && "pointer-events-none opacity-50")}>
          Seguinte
        </Link>
      </div>
    </nav>
  );
}
