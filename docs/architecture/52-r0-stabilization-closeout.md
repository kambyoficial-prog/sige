# R0 — Stabilization & Integration Closeout

Date: 2026-09-30
Status: infrastructure/application stabilization closed; authenticated browser smoke remains an external verification step because Vercel Deployment Protection blocks the available HTTP/browser connector surface.

## Purpose

R0 is the integration gate between the implemented SIGE domain/application architecture and product homologation. It does not add a business module.

## Verified baseline

- R0 merge commit on main: a812dee3884022d3e54d55b78a852088aaa83c24.
- Vercel production deployment for the R0 merge: READY.
- R0 preview deployment for the final fix commit: READY.
- Previous production commit 9777545ca54aa001ebe9cb280cc5584058e178d6: READY.
- Authoritative Supabase project: pfnxvhwpbvlshjjdwbtj.
- RLS remains enabled on critical academic and finance relations.

## Root causes closed in this block

### Registration read privilege

student_registrations had RLS and a SELECT policy but authenticated did not have table SELECT privilege. The authoritative database now grants SELECT to authenticated.

### Enrollment RLS recursion

The enrollments read policy called can_read_student_record(), whose teacher access path called teacher_has_student_access(), which queried student_enrollments again. The teacher-access helper was reworked to derive the relationship from student_course_participations -> teacher_assignments -> teachers, avoiding a self-reference to student_enrollments.

No broad table access or direct authenticated writes were introduced.

### Vercel build determinism

The repository now declares pnpm build as the Vercel build command instead of relying on an external project-level command. Turbo build outputs also exclude .next/cache, following Vercel's monorepo guidance.

## Historical errors requiring fresh deployment verification

The following errors were observed in earlier deployments and must not be treated as current facts until re-tested:

- Server Component to Client Component function serialization.
- permission denied for has_permission.
- permission denied for charge_effective_amount.
- SELECT FOR SHARE in a non-volatile function.
- AUTH_REQUIRED on protected routes.
- SUPABASE_ADMIN_ENV_NOT_CONFIGURED.

Current PostgreSQL privilege inspection confirms authenticated EXECUTE for has_permission and charge_effective_amount.

## R0 verification evidence

### Automated quality gate

- [x] GitHub CI: lint, typecheck, tests and production build all passed on commit 83469a6d713181bde22880d2e5fe83f22d5cdea0.
- [x] Vercel preview: READY on the same final fix commit.
- [x] Vercel production: READY on merge commit a812dee3884022d3e54d55b78a852088aaa83c24.
- [x] Production runtime error scan: no runtime errors in the verification window.
- [x] Preview runtime error scan: no runtime errors in the verification window.

### Database authorization gate

- [x] student_registrations SELECT is granted to authenticated.
- [x] has_permission EXECUTE is granted to authenticated.
- [x] charge_effective_amount EXECUTE is granted to authenticated.
- [x] teacher_has_student_access EXECUTE is granted to authenticated.
- [x] RLS remains enabled on student_enrollments and student_registrations.
- [x] student_enrollments.enrollments_read no longer derives teacher access by querying student_enrollments recursively.

### Application/runtime gate

- [x] Root production request returns HTTP 200 and the expected unauthenticated redirect to /login.
- [x] No current RSC serialization error observed in the final deployment.
- [x] No current RLS recursion or privilege error observed in the final deployment.
- [ ] Authenticated browser smoke for Direction, Secretariat and Teacher still requires a browser session that can pass the project's Vercel Deployment Protection. The available connector surface can inspect the deployment and runtime but cannot establish that browser cookie/session, so this item is intentionally not marked complete.

R0 infrastructure/application stabilization is closed. Product homologation resumes only after the authenticated role smoke is performed in a browser-capable environment; it is not being inferred from build success.

## Non-goals

R0 does not introduce new dashboards, new business entities, alternative authorization systems, client-side business rules, broad service-role access, or UI duplication.
