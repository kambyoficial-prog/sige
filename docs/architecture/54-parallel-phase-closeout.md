# 54 — Parallel phase closeout and release gate

Date: 2026-09-30

## Purpose

Consolidate the real state of R0/F3/F4/F5/F6/F7/F8/F9 after parallel implementation. This document is an evidence ledger, not a declaration that browser evidence exists where it does not.

## Authoritative baseline

- Repository: `kambyoficial-prog/sige`, branch `main`.
- Current production deployment: commit `132e0dde611af20f6e67386a30e993323914b002`, READY.
- Supabase project: `pfnxvhwpbvlshjjdwbtj`, PostgreSQL 17.6, ACTIVE_HEALTHY.
- Main has a newer documentation-only closeout commit; no application/database behavior was changed by that commit.
- Current migration history includes the R0 stabilization migration and all F3–F8 domain migrations.

## Phase state

| Phase | Code / DB | Runtime | Remaining evidence |
|---|---|---|---|
| R0 | Closed | Current production READY; latest two-hour error/fatal runtime scan clean | authenticated browser smoke |
| F3 | Implemented; DB verified | server application boundary verified | role-based browser smoke |
| F4 | Implemented; DB verified | server application boundary verified | role-based browser smoke |
| F5 | Implemented; DB verified | production runtime clean | role-based browser smoke + responsive UI |
| F6 | Implemented; command/read boundaries verified | no current production errors | authenticated gradebook/pauta smoke |
| F7 | Implemented; command/read boundaries verified | finance routes exist; DEMO has no monetary fixtures by design | authenticated finance workflow smoke |
| F8 | Implemented baseline; 8 report projections verified + CSV boundary | production runtime clean | authenticated report/export smoke; PDF/Excel-native rendering is a later document sub-block |
| F9 | Security/application hardening verified; production deployment READY | latest two-hour error/fatal scan clean | final browser/release evidence + Auth password hardening |

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

## Security evidence

The live Supabase audit verified:

- all 58 public SECURITY DEFINER command functions require `auth.uid()`;
- all 58 use the SIGE permission/access-context authorization pattern;
- all 58 pin `search_path`;
- none of the 58 is executable by `anon`;
- critical academic and finance tables remain RLS-protected with explicit policies.

The Advisor finding for authenticated SECURITY DEFINER execution is therefore accepted as an intentional application-command boundary.

One separate security configuration remains outstanding: **Supabase Auth Leaked Password Protection is disabled**. This is a hosted Auth setting and must be enabled in the project's Auth password-security configuration before final release hardening is declared complete.

## Runtime evidence

For 2026-09-30 06:01–08:01 UTC, Vercel production returned no error/fatal runtime logs. Historical error groups remain attached to superseded deployments and are not evidence of the current production state.

React production error #441 means a Server Components render failed; it does not identify the underlying exception by itself. No current production server error corresponding to that code was observed in the latest runtime window. Do not change application architecture from #441 alone; correlate it with the deployment/request and server-side digest first.

## Single remaining Gate B action

The remaining product work is authenticated browser execution against the real deployment:

1. Direction: login, overview, people, enrollment, classes, permissions and permitted financial/report surfaces.
2. Secretariat: login, students, enrollment, class formation, schedules and explicitly permitted operations; confirm finance is not implicitly exposed.
3. Teacher: login, assigned classes, students, subjects, gradebook, timetable and own book of point.
4. Students: directory, profile, enrollment context, class context and access restrictions.
5. Negative checks: cross-class teacher access, unauthorized finance, unauthorized mutations, closed-year writes and direct route access.
6. Responsive and error-state checks on mobile-width and desktop-width surfaces.

No phase is to be marked browser-closed without this evidence. No new product module should be opened before the smoke matrix is archived.

## Engineering decision

The architecture is not to be widened or rewritten at this point. Preserve the domain contracts, verify the real user journeys, fix only observed defects, and close the remaining Auth configuration and browser evidence gates.
