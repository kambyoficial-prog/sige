# 51 — F9 Security and Release Hardening

## Release security model

SIGE uses two distinct database surfaces:

1. **Read surface** — RLS-protected tables and security-invoker projections.
2. **Command surface** — explicit `SECURITY DEFINER` RPCs with:
   - authenticated actor requirement;
   - permission checks;
   - school/academic-year scope validation;
   - temporal locks;
   - domain constraints;
   - idempotency;
   - audit events;
   - explicit `search_path`.

Supabase's generic security advisor flags authenticated execution of these functions. That finding is expected for this architecture because these functions are the deliberate application command API. The important boundary is that `anon` cannot execute them and authenticated users cannot bypass them through direct table writes.

## Release gate

The release gate checks:

- no anonymous execution of core commands;
- no direct authenticated mutation grants on command-owned finance tables;
- RLS enabled on sensitive domain tables;
- report projections use security invoker;
- academic and financial mutations remain command-bound;
- historical/closed-year write barriers remain active.

## Accepted advisor findings

Some advisor findings are intentionally retained:

- command RPCs are SECURITY DEFINER and executable by authenticated users;
- internal command-only tables may have RLS without standalone policies;
- `btree_gist` remains in the public extension schema because timetable exclusion constraints depend on its operator classes and migration of an installed extension is a separate controlled operation.

These are documented architectural decisions, not ignored findings.

## Release verification status

The database release gate has been executed directly against the authoritative SIGE Supabase project. Repository structural assertions are committed under `supabase/tests/0037_f9_security_release_gate.sql`.

CI and browser verification remain separate release gates. CI/application deployment is green in the current production baseline; authenticated browser verification remains the final release evidence.


## Release verification — 2026-09-30

- GitHub CI run #510 is green: lint, TypeScript, domain tests and production build all passed.
- Production build uses `next build --webpack` because the current Turbopack path fails while bundling the native `@tailwindcss/oxide` and `lightningcss` bindings under the repository's pnpm layout. Next.js 16 documents `--webpack` as the supported production fallback.
- Supabase Security Advisor findings remain intentional architectural findings: command APIs are SECURITY DEFINER transaction boundaries; `account_roles`, `app_accounts` and `employments` are internal RLS-protected tables; `btree_gist` remains public because timetable exclusion constraints depend on it.
- The authoritative Supabase project currently exposes 8 reporting read models.
- A SIGE Vercel production deployment now exists and is READY. Runtime error inspection since the current production deployment found no errors. No authenticated browser pass is claimed until the real SIGE login/session flow is exercised.
