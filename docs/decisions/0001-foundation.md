# ADR 0001 — Fundação executável do SIGE

**Status:** accepted  
**Date:** 2026-09-29

## Context

The repository was empty. The product domain and major invariants were analyzed before implementation. The foundation must be reproducible without coupling the domain to a remote Supabase project.

## Decision

Use TypeScript, Next.js App Router, pnpm workspaces, Turborepo, a framework-independent domain package, explicit database/auth boundaries, and repository-managed Supabase migrations/tests.

Remote Supabase mutation is intentionally excluded from this phase.

## Rejected shortcuts

- One Next.js folder containing domain, database and authorization logic.
- Fixed grade columns such as `acs1`, `acs2`, `trabalho1`.
- Permanent `student.class_id` as academic truth.
- Financial totals stored directly on students.
- UI-only authorization.
