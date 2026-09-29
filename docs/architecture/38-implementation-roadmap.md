# 38 — SIGE implementation roadmap

## Status
Approved execution roadmap — 2026-09-29.

This is the execution control document for the product. It prevents isolated screens, duplicated workflows and UI work unsupported by the domain model.

## Current baseline

- Backend/domain: school domain, academic lifecycle, curriculum, assessment, timetable, finance, authorization and application-contract layers are already substantially defined.
- Frontend: Next.js application is currently a minimal shell; design architecture is documented, but the runtime/design-system foundation is not implemented.
- External dependencies: the SIGE Supabase project is not connected here. The currently connected Supabase project belongs to another product and must not be used for SIGE.

## Execution model

We work in large vertical blocks. A block closes only when code, contracts, documentation and verification criteria are coherent.

Every block must answer: user problem, domain contracts, states, explicit non-goals, failure modes, tests and closure evidence.

No placeholder data may masquerade as production data.

## Product roadmap

| Block | Scope | Main output | Gate |
|---|---|---|---|
| F0 | Design-system/runtime foundation | tokens, theme, primitives, shell foundation, accessibility baseline | web compiles + visual verification |
| F1 | Authentication & access context | login, callback, session boundary, capability-derived shell | real auth contract + protected routes | Implemented; runtime auth verification pending SIGE Supabase |
| F2 | Operational primitives | tables, filters, pagination, forms, dialogs, errors, empty/loading states | reusable patterns proven on real queries | Implemented baseline; runtime verification pending |
| F3 | Pessoas & matrícula | students, teachers, guardians, enrollment lifecycle | real commands/queries + no duplicate workflows | Implemented in code; runtime DB verification pending |
| F4 | Estrutura pedagógica | classes, subjects/offers, curriculum, teacher assignments | class workflows use real backend contracts | Implemented in code; runtime DB verification pending |
| F5 | Horários & operações | timetable, calendar, class sessions, livro de ponto | conflict-aware workflow + responsive verification |
| F6 | Avaliação & pautas | gradebook, publication, results, reports | deterministic results + period/year state |
| F7 | Financeiro | obligations, payments, allocations, receipts, balances, transport | year-scoped financial lifecycle |
| F8 | Relatórios & documentos | reports, exports, PDF/print surfaces | document correctness and auditability |
| F9 | Hardening & release | security, accessibility, performance, browser QA, deployment | release checklist fully green |

## Cross-cutting gates

- stable application error codes;
- permission-derived navigation;
- server-side authorization;
- audit/idempotency propagation;
- URL-addressable query state;
- responsive behavior;
- keyboard/focus accessibility;
- observability and correlation IDs;
- security headers and cache policy;
- no client-side business-rule duplication;
- generated database types after SIGE database connection;
- migration/test verification on an authorized PostgreSQL/Supabase environment.

## F0 — Design-system/runtime foundation

Status: implemented baseline; runtime verification remains pending in CI-capable environment.

Deliver:
- Tailwind CSS v4 + shadcn/ui foundation;
- semantic light/dark tokens;
- typography, spacing, radius and elevation rules;
- class composition utility;
- core Button and feedback primitives;
- application shell primitives;
- typed navigation model;
- accessible focus and reduced-motion baseline;
- root metadata and language configuration.

Explicitly do not build fake dashboards, fake records, fake authentication, charts without data contracts, a global client store or a second component system.

## F1 — Authentication & access

Status: implemented baseline; runtime verification pending authorized SIGE Supabase.

- real Supabase Auth sign-in;
- callback/session handling;
- protected application routes;
- current access context;
- capability-derived navigation;
- session expiry/re-authentication;
- authorization failures that never expose backend internals.

## F2 — Operational primitives

Status: implemented baseline; runtime verification pending CI/browser environment.

- data-table primitives;
- server-backed search/filter state;
- pagination;
- field/form patterns;
- confirmation dialogs;
- page error boundaries;
- empty/no-result states;
- safe optimistic updates only where justified;
- mutation feedback and duplicate-submit protection.

## F3 — Pessoas & matrícula

Status: implemented in code; runtime verification pending authorized SIGE database.

Canonical surfaces:
- student directory;
- student profile;
- teacher directory/profile;
- guardian context;
- admission/enrollment workflow;
- class placement context;
- enrollment lifecycle/history.

The student profile is contextual and read-oriented. Editing occurs through focused operations.

## F4 — Estrutura pedagógica

Status: implemented in code; runtime verification pending authorized SIGE database.

- class groups;
- curriculum/subject configuration;
- course offerings;
- teacher assignments;
- director de turma;
- class overview/roster/teachers;
- class transfer.

A/B/C-style labels remain configurable section/pathway data, never hardcoded business logic.

## F5 — Operações

Status: operational vertical slice implemented; database runtime verification completed for the command boundary and RLS gate. Browser QA remains pending because SIGE is not connected to a Vercel project in the available account.

Implemented in the current vertical slice:
- timetable grid by class;
- class-session command boundary;
- session lifecycle `OPEN → CLOSED`;
- session creation anchored to a real schedule entry;
- calendar/day and schedule-validity guards;
- teacher-own-session authorization;
- attendance command scoped to enrolled students in the scheduled class;
- idempotent/audited session and attendance mutations;
- removal of direct authenticated writes to sessions and attendance;
- `class_session_directory` and `class_session_roster` read projections;
- operational livro de ponto UI.

Still open:
- dedicated teacher timetable surface;
- dedicated student timetable surface;
- richer schedule planning/distribution UI;
- browser QA;
- execution of PostgreSQL suite against the authorized SIGE database.

Scheduling remains a constrained operational tool, not a generic calendar.

## F6 — Avaliação

- assessment-period context;
- teacher gradebook;
- configurable assessment components;
- draft/published states;
- trimester results;
- exam/result workflow;
- final results;
- recovery only after its normative formula is verified and versioned;
- pauta print/export.

The UI never calculates official results independently from the backend engine.

## F7 — Financeiro

- fee/obligation configuration;
- student obligations by academic year;
- payment capture;
- allocation;
- reversal;
- receipt;
- year-scoped balances;
- optional transport service/charges.

Payment and charge state remain distinct in the UI.

## F8 — Relatórios & documentos

Expose only reports backed by real projections/queries. Initial families: enrollment statistics, M/F distribution, initial/final enrollment, withdrawals, cancellations, transfers, class rosters, teacher/class reports, academic results/pautas, financial statements and required printable documents.

## F9 — Release hardening

Security: Supabase Security/Performance Advisor review, SECURITY DEFINER audit, RLS/function-grant review, session/cache review, secret scan and destructive-operation review.

Quality: TypeScript, lint, production build, database migration suite, browser smoke tests, accessibility audit, responsive verification, recovery scenarios and performance budgets.

A release is not declared ready from a green TypeScript build alone. Executable evidence from database, application build and browser is required.

## Decision gates

- Gate A — Foundation: F0/F1 complete, real application shell and authentication, no fake data.
- Gate B — School operations: F2–F5 complete enough for secretary and teachers to perform the operational workflow end-to-end.
- Gate C — Academic truth: F6 complete with verified rules and published-result behavior.
- Gate D — Financial truth: F7 complete with year scoping, reversals and receipts.
- Gate E — Release: F8/F9 complete with evidence archived.

## Working rule

When a new requirement appears, place it into this roadmap before implementing it. If it conflicts with an existing decision, update the relevant architecture document first. Do not solve architectural questions inside a component file.
