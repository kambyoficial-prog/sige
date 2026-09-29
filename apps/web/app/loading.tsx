export default function Loading() {
  return (
    <main className="min-h-svh bg-background px-6 py-8">
      <div className="mx-auto flex min-h-[calc(100svh-4rem)] max-w-6xl items-center justify-center">
        <div className="text-center">
          <div className="mx-auto mb-4 size-5 animate-pulse rounded-full bg-muted" aria-hidden="true" />
          <p className="text-sm text-muted-foreground">A carregar o SIGE…</p>
        </div>
      </div>
    </main>
  );
}
