"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu } from "lucide-react";

import { navigationSections } from "@/lib/navigation";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";
import { SignOutButton } from "@/components/auth/sign-out-button";

type AppShellProps = {
  children: React.ReactNode;
  permissions?: ReadonlySet<string>;
  personName?: string;
  schoolName?: string;
  academicYearLabel?: string;
};

export function AppShell({
  children,
  permissions = new Set(),
  personName = "Utilizador",
  schoolName = "SIGE",
  academicYearLabel,
}: AppShellProps) {
  const pathname = usePathname();
  const visibleSections = navigationSections
    .map((section) => ({
      ...section,
      items: section.items.filter((item) => !item.permission || permissions.has(item.permission)),
    }))
    .filter((section) => section.items.length > 0);

  return (
    <div className="min-h-svh bg-background text-foreground">
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-border bg-background lg:flex lg:flex-col">
        <div className="border-b border-border px-5 py-5">
          <p className="text-sm font-semibold tracking-tight">{schoolName}</p>
          {academicYearLabel ? <p className="mt-1 text-xs text-muted-foreground">{academicYearLabel}</p> : null}
        </div>
        <nav aria-label="Navegação principal" className="flex-1 overflow-y-auto px-3 py-4">
          {visibleSections.map((section) => (
            <div key={section.label} className="mb-5 last:mb-0">
              <p className="px-2 pb-2 text-[11px] font-medium uppercase tracking-[0.08em] text-muted-foreground">
                {section.label}
              </p>
              <div className="space-y-0.5">
                {section.items.map((item) => {
                  const active = pathname === item.href || (item.href !== "/" && pathname.startsWith(`${item.href}/`));
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      aria-current={active ? "page" : undefined}
                      className={cn(
                        "flex min-h-9 items-center rounded-md px-2.5 text-sm transition-colors",
                        active ? "bg-accent font-medium text-accent-foreground" : "text-muted-foreground hover:bg-accent hover:text-foreground",
                      )}
                    >
                      {item.label}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>
        <div className="border-t border-border p-3">
          <div className="flex items-center gap-2 rounded-md px-2 py-2">
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{personName}</p>
              <p className="text-xs text-muted-foreground">Conta ativa</p>
            </div>
            <ThemeToggle />
          </div>
          <SignOutButton />
        </div>
      </aside>

      <header className="sticky top-0 z-30 border-b border-border bg-background/95 px-4 backdrop-blur lg:hidden">
        <div className="flex h-14 items-center justify-between">
          <details className="relative">
            <summary className="flex size-9 cursor-pointer list-none items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring">
              <Menu aria-hidden="true" />
              <span className="sr-only">Abrir navegação</span>
            </summary>
            <div className="absolute left-0 top-11 z-40 w-[min(20rem,calc(100vw-2rem))] rounded-lg border border-border bg-popover p-2 text-popover-foreground shadow-xl">
              {visibleSections.map((section) => (
                <div key={section.label} className="px-1 py-2">
                  <p className="px-2 pb-1 text-[10px] font-medium uppercase tracking-[0.08em] text-muted-foreground">{section.label}</p>
                  {section.items.map((item) => (
                    <Link key={item.href} href={item.href} className="block rounded-md px-2 py-2 text-sm hover:bg-accent">{item.label}</Link>
                  ))}
                </div>
              ))}
            </div>
          </details>
          <p className="text-sm font-semibold tracking-tight">{schoolName}</p>
          <ThemeToggle />
        </div>
      </header>

      <main className="min-h-svh lg:pl-64">
        <div className="mx-auto w-full max-w-[1600px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</div>
      </main>

    </div>
  );
}
