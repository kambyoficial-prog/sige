# 36 — Backend closeout

## Closed

The SIGE backend now has a defined boundary from database to application:

- PostgreSQL domain model and invariants;
- RLS and scoped authorization;
- transactional domain commands;
- idempotency;
- audit trail;
- academic lifecycle;
- curriculum engine;
- assessment engine;
- result ledger;
- financial lifecycle;
- timetable integrity;
- closed-year write barrier;
- authenticated access context;
- typed TypeScript command contracts;
- typed query DTOs;
- server-only Supabase boundary;
- Next.js 16 SSR Auth with PKCE and proxy session refresh;
- stable application error normalization;
- CI quality pipeline;
- backend architecture documentation.

## Explicit non-goals

The backend does not put official academic calculations in TypeScript.

The backend does not authorize from UI state, user metadata or role labels supplied by the browser.

The backend does not use service_role credentials in the web runtime.

The backend does not silently reopen closed academic years.

The backend does not invent a recovery formula where the normative source is not sufficiently verified.

## Verification gate

The remaining work is operational verification, not domain design:

1. authorize the actual SIGE Supabase project;
2. run migrations on a clean PostgreSQL/Supabase database;
3. run SQL regression tests 0004 through 0028, including any existing test 0015 if present in the repository;
4. run Supabase advisors;
5. generate the real database TypeScript types from the deployed schema;
6. generate and commit pnpm-lock.yaml;
7. run CI successfully: lint, typecheck, test and build;
8. execute authenticated smoke tests with real SIGE roles.

Until those gates are executed, the backend is considered **implementation-complete but not runtime-verified**.

## Frontend planning boundary

Frontend planning can start now against the contracts already defined.

The frontend plan should consume backend capabilities rather than redesign them. It should map screens and workflows to:

- access context;
- query projections;
- command contracts;
- application error codes;
- lifecycle states;
- role/permission capabilities.

Any frontend requirement that cannot be expressed through an existing backend contract becomes a backend change request, not a client-side workaround.
