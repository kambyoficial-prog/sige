# 54 — Parallel phase closeout and release gate

Date: 2026-09-30

## Purpose

Consolidate the real state of R0/F3/F4/F5/F6/F7/F8/F9 after parallel implementation. This document is an evidence ledger, not a declaration that browser evidence exists where it does not.

## Authoritative baseline

- Repository: `kambyoficial-prog/sige`, branch `main`.
- Current production commit: `132e0dde611af20f6e67386a30e993323914b002`.
- Vercel production deployment for that commit: READY.
- Supabase project: `pfnxvhwpbvlshjjdwbtj`, PostgreSQL 17.6, ACTIVE_HEALTHY.
- Current migration history includes the R0 stabilization migration and all F3–F8 domain migrations.

## Phase state

| Phase | Code / DB | Runtime | Remaining evidence |
|---|---|---|---|
| R0 | Closed | Current production READY; no runtime errors observed after current deployment | authenticated browser smoke |
| F3 | Implemented; DB verified | server application boundary verified | role-based browser smoke |
| F4 | Implemented; DB verified | server application boundary verified | role-based browser smoke |
| F5 | Implemented; DB verified | production runtime clean | role-based browser smoke + responsive UI |
| F6 | Implemented; command/read boundaries verified | no current production errors | authenticated gradebook/pauta smoke |
| F7 | Implemented; command/read boundaries verified | finance routes exist; DEMO has no monetary fixtures by design | authenticated finance workflow smoke |
| F8 | Implemented baseline; 8 report projections verified + CSV boundary | production runtime clean | authenticated report/export smoke; PDF/Excel-native rendering is a later document sub-block |
| F9 | Security/application hardening verified; production deployment READY | no errors after current deployment | final browser/release evidence |

## Database evidence

Current DEMO cardinalities:

- students: 6
- enrollments: 6
- class groups: 3
- course offerings: 24
- teacher assignments: 24
- subject participations: 48
- assessment periods: 3
- assessments: 40 OPEN
- assessment results: 48 PUBLISHED at assessment level
- academic results: 0 PUBLISHED — expected until official result calculation/publication commands are executed
- charges/payments/allocations: 0 — intentional; no school-approved financial tariff was fabricated into DEMO data

Command existence was verified for assessment, academic-result, finance and class-session mutation boundaries. Reporting projections, gradebook/pauta projections and timetable/session projections have authenticated SELECT grants.

## Security Advisor disposition

The remaining Advisor findings are not treated as automatic defects:

- command RPCs are deliberate SECURITY DEFINER application boundaries;
- `account_roles`, `app_accounts` and `employments` are internal RLS-protected tables;
- `btree_gist` is retained in public because timetable exclusion constraints depend on it;
- multiple permissive policies and missing FK indexes remain hardening candidates and must be addressed based on query plans/authorization semantics, not blindly removed;
- unused-index findings are not grounds for deletion before representative production workload exists.

## Runtime evidence

For the interval beginning 2026-09-30 07:50 UTC, Vercel reports no runtime error groups and no production error/fatal log counts. Older error groups are tied to superseded deployments and are not evidence of the current production state.

## Single remaining Gate B action

The remaining work is not another architectural rewrite. It is authenticated browser execution against the real deployment:

1. Direction: login, overview, people, enrollment, classes, permissions and permitted financial/report surfaces.
2. Secretariat: login, students, enrollment, class formation, schedules and explicitly permitted operations; confirm finance is not implicitly exposed.
3. Teacher: login, assigned classes, students, subjects, gradebook, timetable and own book of point.
4. Negative checks: cross-class teacher access, unauthorized finance, unauthorized mutations, closed-year writes and direct route access.
5. Responsive and error-state checks on mobile-width and desktop-width surfaces.

No phase is to be marked browser-closed without this evidence. No new product module should be opened before the smoke matrix is archived.

## Engineering decision

The architecture is not to be widened or rewritten at this point. The system has reached an integration/homologation boundary: preserve the domain contracts, verify the real user journeys, fix only observed defects, then move the release gate forward.
