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

## SECURITY DEFINER audit — 2026-09-30

The authoritative database was inspected directly.

- 58 public `SECURITY DEFINER` functions are exposed to `authenticated`; these are the intentional command/application boundaries.
- All 58 inspected functions require an authenticated actor through `auth.uid()`.
- All 58 contain the permission/access-context check pattern used by the SIGE command layer.
- All 58 pin `search_path`.
- No public `SECURITY DEFINER` function in this set is executable by `anon`.
- Critical exposed domain tables retain RLS and explicit policies: students, enrollments/registrations, class groups, offerings, teacher assignments, participations, assessments/results, sessions and finance relations.

Therefore the 58-function Advisor warning is **accepted by design**, but only because the underlying authorization invariants were verified in the live database. Replacing these RPCs with direct authenticated table writes would weaken the architecture and is explicitly rejected.

## Accepted advisor findings

Some advisor findings are intentionally retained:

- command RPCs are SECURITY DEFINER and executable by authenticated users;
- internal command-only tables may have RLS without standalone policies;
- `btree_gist` remains in the public extension schema because timetable exclusion constraints depend on its operator classes and migration of an installed extension is a separate controlled operation.

These are documented architectural decisions, not ignored findings.

## Outstanding security configuration

Supabase Security Advisor currently reports **Leaked Password Protection disabled**.

Supabase documents this control as password screening against the HaveIBeenPwned Pwned Passwords API and recommends enabling it for password-based authentication. It is a hosted Auth configuration, not a PostgreSQL migration, so it is not changed through the repository schema. This remains an explicit release-hardening action in the Supabase Auth settings.

Reference: https://supabase.com/docs/guides/auth/password-security

## Release verification status

The database release gate has been executed directly against the authoritative SIGE Supabase project. Repository structural assertions are committed under `supabase/tests/0037_f9_security_release_gate.sql`.

CI and browser verification remain separate release gates. CI/application deployment is green in the current production baseline; authenticated browser verification remains the final product evidence.

## Release verification — 2026-09-30

- GitHub CI run #510 is green: lint, TypeScript, domain tests and production build all passed.
- Production build uses `next build --webpack` because the current Turbopack path fails while bundling the native `@tailwindcss/oxide` and `lightningcss` bindings under the repository's pnpm layout.
- Supabase Security Advisor findings were reclassified using live authorization evidence rather than by suppressing or blindly revoking grants.
- The authoritative Supabase project currently exposes 8 reporting read models.
- A SIGE Vercel production deployment exists and is READY.
- Production runtime logs for the latest two-hour verification window contained no error/fatal entries.
- No authenticated browser pass is claimed until the real SIGE login/session flow is exercised.
