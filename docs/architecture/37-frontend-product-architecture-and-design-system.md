# 37 — Frontend product architecture and design system

## Status
Decision record — frontend planning baseline.

This document defines the frontend product architecture before implementation. The goal is to minimize interface surface, duplication, cognitive load and visual noise while preserving the workflows required by the school domain.

## 1. Product principle
SIGE is an operational system, not a generic analytics dashboard.

The interface must optimize for:
1. finding the correct person, class, subject or financial record;
2. completing a concrete school operation;
3. understanding the current state and what can be done next;
4. preventing invalid operations before submission;
5. recovering from errors without losing work;
6. preserving context while moving between related records.

The frontend must not invent domain behavior. PostgreSQL and the application command/query contracts remain the source of truth.

## 2. Benchmark conclusions
The benchmark reviewed current patterns from mature product and enterprise systems, including Infinite Campus, openSIS, Veracross, Linear, Carbon Design System, Atlassian Design System and the shadcn ecosystem.

### Student information is contextual
Infinite Campus separates student information from the tools that modify it. Student views group grades by enrollment/course and expose contextual schedule and profile information. Its gradebook is scoped by year/term/section/task rather than being a generic spreadsheet.

Decision: a student profile is a contextual workspace, not a giant form. Read-oriented information and mutations are separated.

### Grade entry is a work surface
Mature SIS gradebooks establish context first, then expose students and assessment items. This is preferable to a generic Notes page containing unrelated selectors and controls.

Decision: teacher grade entry will use a dense, keyboard-friendly table optimized for repeated data entry. Configuration remains outside the entry surface.

### Scheduling is constraint-oriented
School systems expose teacher/student/course selection and availability/conflict validation rather than expecting users to reason about every constraint themselves.

Decision: timetable UI will show conflicts as domain feedback and preserve the current scheduling context. It will not expose raw database constraints.

### Role-based navigation is fundamental
openSIS separates administrator and teacher experiences and limits navigation by role. Veracross describes a unified data model with workflows organized around school departments.

Decision: navigation is capability-driven. A user sees operations relevant to permissions granted in the current school context. We do not show disabled menu items merely to advertise unavailable functionality.

### Enterprise systems distinguish notification severity
Carbon distinguishes inline, toast, actionable and callout notifications. Atlassian treats empty states as part of the recovery path.

Decision:
- field error for field-level validation;
- form/section error for server validation;
- toast for short-lived completion feedback;
- blocking dialog only for destructive/high-consequence confirmation;
- page state for unavailable/failed data loading.

We will not use a toast as the only explanation for a failed form submission.

### Navigation preserves context
Linear emphasizes consistent headers/navigation and contextual command surfaces.

Decision: use a stable application shell, predictable page headers and contextual actions. Keyboard shortcuts are optional enhancements, never required for operation.

## 3. Visual direction
Target: restrained enterprise interface with the visual discipline of high-quality modern software products.

Reference principles, not copied branding:
- Apple: hierarchy, whitespace, typography and restraint.
- Linear: dense but calm operational surfaces and consistent navigation.
- Stripe: information hierarchy and clear financial states.
- Vercel/shadcn: composable primitives and clean technical foundation.
- Carbon/Atlassian: mature interaction and error patterns.

Awwwards-level quality applies to visual craft and responsive execution, not decorative animation. SIGE is an operational product; decoration must never compete with task completion.

Explicitly rejected:
- glassmorphism as a default;
- oversized hero sections inside the authenticated product;
- gradients used as decoration;
- floating KPI cards without operational purpose;
- excessive rounded cards;
- animated counters;
- arbitrary charts;
- duplicate create/add buttons;
- decorative empty states;
- fake activity feeds;
- AI chat/copilot UI;
- smart recommendations without a real domain requirement;
- terminology copied from software products instead of school operations.

## 4. Application shell
Desktop:
- persistent left navigation;
- compact top context/header;
- main content area with controlled maximum width;
- optional contextual right-side panel only when it materially improves the workflow.

The shell must expose:
- school identity;
- current academic year/context where relevant;
- current user;
- navigation allowed by capability;
- session/account actions.

The shell must not expose every possible module globally.

Mobile:
- primary navigation becomes a mobile navigation surface;
- tables become intentional mobile representations rather than horizontal overflow by default;
- dense operational tasks may remain optimized for tablet/desktop when the task inherently requires a wide grid;
- forms become single-column where needed;
- destructive actions remain explicit;
- touch targets remain accessible.

## 5. Information architecture
First navigation model is organized by school work, not database tables:

### Visão geral
Operational landing page for the current role.

### Pessoas
- Alunos
- Professores
- Encarregados / guardians when the workflow requires it

### Matrículas
- Matrículas
- Inscrições / placement context where required

### Pedagógico
- Turmas
- Disciplinas / ofertas
- Notas
- Pautas
- Currículo / configuration for authorized users

### Operações
- Horários
- Livro de ponto
- Calendário / academic operations

### Financeiro
- Propinas / obrigações
- Pagamentos
- Saldos
- Transporte where enabled

### Relatórios
Only reports supported by real backend projections and school requirements.

### Administração
Only for capabilities that actually exist and are authorized.

This is a planning taxonomy. Final visible navigation is generated from role/capability and actual product availability.

## 6. No duplicate surfaces
Each operation has one canonical entry point.

Examples:
- create student: one canonical enrollment/person workflow;
- view student: one canonical student profile;
- assign teacher: one canonical assignment workflow;
- enter grades: one gradebook workflow;
- print/issue a report: contextual action from the relevant record;
- payments: one financial workflow with contextual allocation;
- class transfer: one operation from the class/student context.

A shortcut may deep-link to the canonical workflow, but must not create a second implementation of the same operation.

## 7. Page anatomy
Most operational pages follow:
1. page header;
2. contextual description only when needed;
3. primary action;
4. filters/search when the dataset requires them;
5. primary content surface;
6. contextual secondary information;
7. pagination or continuation.

Avoid title -> four KPI cards -> chart -> another card -> table unless the KPIs and chart directly answer a real operational question.

## 8. Dashboard policy
A dashboard exists to answer:
- what requires attention now?
- what operation is incomplete?
- what changed materially?
- where is intervention required?

It is not a gallery of statistics.

### Secretaria
Potential operational indicators:
- matrícula pending/incomplete;
- turmas needing formation;
- schedules with unresolved conflicts;
- documents/processes requiring action.

### Direção
Potential indicators:
- current enrollment;
- financial obligations/payment status;
- academic publication status;
- year/period state;
- unresolved operational exceptions.

### Direção Pedagógica
Potential indicators:
- assessment periods;
- grade publication state;
- class/teacher assignment state;
- timetable conflicts;
- academic result completion.

### Professor
Do not build an administrative dashboard. The useful landing surface is:
- today's/next classes;
- assigned classes;
- pending grade-entry work;
- relevant timetable.

Every metric must have a source, a purpose and a destination.

## 9. Data tables
Tables are first-class operational components.

Use shadcn table primitives with TanStack Table where behavior requires sorting/filtering/pagination/selection.

Rules:
- visible columns must represent decisions the user makes;
- row actions stay contextual;
- filters are progressive, not a wall of controls;
- search is server-backed for large datasets;
- selection is only present when bulk actions exist;
- column visibility is only present when useful;
- pagination is explicit;
- loading, empty, error and no-result states are distinct;
- mobile representation is defined per table.

Do not create one universal DataTable abstraction that attempts to solve every workflow. Shared primitives should exist; workflow-specific behavior remains local.

## 10. Forms
Use React Hook Form + Zod with shadcn Field patterns.

Rules:
- required fields are visibly identified;
- optional fields are explicitly marked where ambiguity exists;
- group related fields;
- use controlled selection inputs for constrained domain values;
- validate locally before submit;
- validate again against backend responses;
- preserve user input after server errors;
- focus the first actionable error when appropriate;
- disable the submit action during an active mutation to prevent duplicates;
- never hide a server/domain error behind a generic something went wrong.

Long workflows should be split by meaningful domain sections, not arbitrary wizard steps.

## 11. Error model
Frontend consumes the backend stable application error codes.

Never branch on PostgreSQL text or Supabase implementation errors.

| Backend condition | UI treatment |
| --- | --- |
| Validation error | field/section error |
| Permission denied | clear access message; no misleading retry |
| Conflict | contextual conflict explanation + corrective action |
| Closed academic year | explicit read-only/closed state |
| Duplicate/idempotency | preserve successful result semantics where applicable |
| Authentication/session | redirect/re-auth flow |
| Network/transient | retry where safe |
| Unexpected server failure | concise error + correlation reference when available |

Error messages must use school vocabulary and describe the next useful action.

## 12. Toast policy
Sonner is the default transient feedback mechanism.

Use toast for:
- successful small mutations;
- completion of background-safe actions;
- non-blocking system feedback.

Do not use toast as:
- a form validation surface;
- the only error explanation for a failed operation;
- a replacement for confirmation of destructive actions;
- a persistent status indicator.

Toast text should be short and specific.

## 13. Confirmation policy
Use confirmation only when the action has meaningful consequences.

Examples:
- closing an academic year;
- reversing a confirmed payment;
- destructive deletion where deletion is actually supported;
- irreversible publication/finalization.

Do not confirm routine actions such as saving a normal form.

Confirmation copy must name the object and consequence.

## 14. Loading and empty states
Every query surface defines four states:
1. loading;
2. populated;
3. empty/no matching data;
4. failed.

Empty does not mean error.

Examples:
- no students in a class = valid empty state;
- search returned no students = no-results state;
- failed database request = error state;
- user lacks permission = access state.

Skeletons are used where layout is stable and the wait benefits from structural continuity. Spinners are used for short actions. Long operations need explicit progress.

## 15. Charts
Charts use shadcn chart primitives over Recharts where visualization adds information.

Allowed examples:
- enrollment evolution;
- M/F distribution where the report requires it;
- financial receivable/payment evolution;
- assessment completion/publication status;
- operational trend over time.

Not allowed:
- chart for a single number;
- chart that duplicates a table without improving interpretation;
- decorative pie/donut charts;
- arbitrary performance scores invented by the UI.

Every chart needs:
- source query;
- time/context scope;
- accessible textual summary;
- empty state;
- meaningful tooltip/labels.

## 16. Typography and language
Product language is Portuguese appropriate to school operations in Mozambique.

Prefer:
- Aluno
- Professor
- Turma
- Disciplina
- Ano letivo
- Matrícula
- Propina
- Pagamento
- Saldo
- Pauta
- Avaliação
- Exame
- Recuperação only where the domain supports it.

Avoid technical labels such as CRUD, entity, mutation, query, record, workspace or pipeline in operational UI.

## 17. Accessibility
Baseline:
- semantic HTML;
- keyboard operation;
- visible focus;
- labels associated with controls;
- errors announced and visually associated;
- sufficient contrast;
- logical heading hierarchy;
- no information conveyed by color alone;
- reduced-motion support;
- touch targets appropriate to the context.

Radix/shadcn primitives are preferred because they provide established accessibility behavior, but implementation must still be tested in context.

## 18. Component strategy
### Shared primitives
shadcn/ui components will form the base:
- Button
- Input
- Textarea
- Select/Combobox
- Field
- Checkbox
- Radio Group
- Switch
- Dialog/Alert Dialog
- Sheet
- Dropdown Menu
- Popover
- Tabs
- Tooltip
- Table
- Badge
- Skeleton
- Sonner
- Chart

Add only when a real workflow requires it.

### Product components
Create domain components only after at least two real workflows justify reuse.

Examples:
- StudentIdentity
- AcademicContextBar
- StatusBadge
- MoneyAmount
- AssessmentGrid
- ClassRoster
- TimetableGrid
- ErrorSummary
- EmptyState
- PageHeader

Avoid generic abstractions whose only purpose is reducing file count.

## 19. State management
Default:
- Server Components for server data and initial rendering.
- URL state for shareable/filterable view state.
- Local component state for ephemeral UI state.
- React Hook Form for form state.
- No global state library initially.

A global client store is introduced only if a concrete cross-route interaction requires it.

## 20. Data fetching boundary
Pages consume typed query functions from the application boundary.

Mutation flow:
UI -> typed command -> server application layer -> Supabase RPC -> PostgreSQL

Query flow:
UI/server component -> typed query -> projection -> UI

The frontend must never call arbitrary Supabase RPC names from components.

## 21. Responsive design contract
Breakpoints are chosen from content failure, not device names.

For each workflow define:
- minimum supported width;
- collapse behavior;
- mobile information priority;
- table strategy;
- action placement;
- keyboard behavior.

A responsive review is required for:
- 1440px desktop;
- 1024px tablet/small desktop;
- 768px tablet;
- 390px mobile.

## 22. Animation
Motion is functional.

Allowed:
- navigation transitions where they improve orientation;
- dialog/sheet entrance;
- loading feedback;
- table/filter state transitions;
- subtle hover/focus transitions.

Avoid:
- perpetual animation;
- decorative page transitions;
- large parallax;
- animated KPI counters;
- motion that delays routine operations.

Respect prefers-reduced-motion.

## 23. Proposed frontend phases
### F1 — Design foundation
- shadcn initialization;
- Tailwind/theme tokens;
- typography;
- icon policy;
- light/dark themes;
- application shell;
- navigation capability model;
- shared feedback/error primitives.

### F2 — Authentication and access context
- login;
- callback/session states;
- unauthorized;
- forbidden;
- session expiration;
- role-aware shell.

### F3 — Operational primitives
- tables;
- search/filter;
- forms;
- dialogs;
- confirmation;
- empty/loading/error states;
- pagination;
- URL state.

### F4 — People and enrollment
- student list;
- student profile;
- enrollment workflow;
- teacher list/profile;
- guardian context.

### F5 — Academic operations
- class groups;
- class roster;
- teachers/assignments;
- curriculum context;
- timetable.

### F6 — Assessment
- teacher gradebook;
- assessment setup;
- publication state;
- student/class results;
- printable grade views.

### F7 — Finance
- obligations;
- payment;
- allocations;
- reversals;
- receipts;
- balances by academic year.

### F8 — Reports and documents
- operational reports;
- export/print;
- PDF/Excel where the backend/report contract supports it.

### F9 — QA and hardening
- responsive QA;
- accessibility;
- error-path testing;
- permission matrix;
- browser verification;
- performance;
- visual consistency.

## 24. Definition of done for every screen
A screen is not complete when it visually renders.

It must have:
- correct role/capability access;
- real query/command contract;
- loading state;
- empty state;
- no-results state where relevant;
- error state;
- permission state where relevant;
- mutation loading state;
- success feedback;
- validation;
- responsive behavior;
- keyboard/focus behavior;
- correct Portuguese terminology;
- no duplicate operation;
- no invented domain state;
- no placeholder data in production paths.

## 25. Initial dependency decision
Required/approved direction:
- Next.js 16 App Router
- React 19
- TypeScript
- Tailwind CSS
- shadcn/ui
- Radix primitives where used by shadcn components
- TanStack Table for advanced data tables
- React Hook Form
- Zod
- Sonner
- Recharts through shadcn chart components
- Lucide icons, used consistently

Not initially approved:
- Zustand/global client store
- Redux
- Framer Motion
- a second component library
- a second form library
- a second table library
- a generic charting abstraction
- an AI/copilot UI framework

A dependency may be added only when a concrete requirement cannot be met cleanly with the existing stack.

## 26. Engineering rule
The frontend must make the correct operation obvious without making the system look simplistic.

The test is not whether a page looks impressive.

The test is whether a secretary, director or teacher can complete the intended school operation quickly, understand what happened, recover from an error, and avoid accidentally performing an operation outside their authority.
