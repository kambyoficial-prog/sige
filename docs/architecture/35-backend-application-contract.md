# 35 — Backend application contract

## Objective

The backend is divided into three authorities:

1. PostgreSQL/Supabase — domain truth, authorization, invariants and transactions.
2. Server application layer — authenticated boundary, typed commands/queries and error normalization.
3. Frontend — presentation and interaction only.

The frontend must never become a second domain engine.

## Command boundary

apps/web/lib/sige/commands.ts is the only application-layer entry point for domain commands.

It:

- requires an authenticated Supabase session;
- maps TypeScript camelCase input to PostgreSQL command parameters;
- always forwards idempotency;
- optionally forwards a request hash;
- calls only known RPC names;
- normalizes database errors into SigeApplicationError.

The database remains responsible for permission, school scope, year scope, lifecycle, transactionality, business invariants and audit.

## Query boundary

apps/web/lib/sige/queries.ts exposes read models rather than arbitrary table access.

Current projections include:

- class group overview;
- students in a class;
- teachers in a class;
- class timetable;
- teacher timetable;
- student timetable;
- teacher workload;
- student financial balance by academic year;
- academic year history;
- assessment period history.

All query entry points require authentication and rely on database RLS/security-invoker views for authorization.

## Authentication

The Next.js application uses:

- @supabase/ssr;
- cookie-based sessions;
- PKCE;
- getClaims() for server-side token verification;
- Next.js 16 proxy.ts for session refresh.

getSession() is not used as the authorization source.

No service_role key exists in the browser contract.

## Access context

current_access_context() provides the authenticated application context:

- auth user;
- application account;
- person;
- school memberships;
- roles;
- effective permissions.

This is a read model. It does not replace permission checks inside commands.

## Error contract

PostgreSQL domain errors are normalized to stable application codes.

The frontend should branch on SigeApplicationError.code, not on PostgreSQL message text.

Unknown database errors remain UNKNOWN; they are not silently translated into a successful or generic domain state.

## Idempotency

Every mutating domain command requires an idempotency key.

The application layer never generates a key implicitly for a business mutation. The caller owns the command identity.

Retries therefore remain explicit and traceable.

## Financial projection

Financial balances are grouped by school, student and academic year.

A payment may remain independent from an academic year and can allocate to a year-bound charge. The balance projection preserves the charge's academic year.

## Runtime

The application baseline is Node 22. Supabase's current JavaScript SDK no longer supports Node 20, so the previous Node 20 floor was removed.

Dependencies are pinned rather than floating:

- @supabase/ssr 0.12.7
- @supabase/supabase-js 2.117.2
- server-only 0.0.1

## Verification status

The code and SQL contracts have been reviewed against the repository.

Still required before declaring operational production readiness:

1. connect the actual SIGE Supabase project;
2. execute the complete migration chain against a clean PostgreSQL instance;
3. execute all SQL regression tests;
4. run Supabase security/performance advisors;
5. generate database.types.ts from the real schema;
6. install dependencies and generate the pnpm lockfile;
7. run pnpm typecheck, pnpm lint, pnpm build;
8. run browser-level smoke tests;
9. validate real Auth users, roles and school memberships.

These are verification gates, not reasons to duplicate domain logic in the frontend.

## Frontend readiness rule

The frontend can now be planned against this contract.

It must consume:

- command inputs from @sige/contracts;
- query DTOs from @sige/contracts;
- access context from getCurrentAccessContext;
- normalized application errors.

It must not:

- write directly to critical tables;
- reproduce academic formulas;
- infer permissions;
- calculate official grades;
- bypass command RPCs;
- treat UI state as lifecycle state.
