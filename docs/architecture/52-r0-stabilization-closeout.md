# R0 — Stabilization & Integration Closeout

Date: 2026-09-30
Branch: fix/r0-stabilization-boundaries

## Purpose

R0 is the integration gate between the implemented SIGE domain/application architecture and product homologation. It does not add a business module.

## Verified baseline

- GitHub main: 194b82c4b81894a57785a32cfa69e634bfe5efc7.
- Vercel production for that commit: ERROR at buildStep.
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

## R0 exit criteria

All must be true:

- [ ] GitHub CI green.
- [ ] Vercel production build READY.
- [ ] No new RSC serialization errors.
- [ ] No RLS recursion errors.
- [ ] No unexpected function/table privilege errors.
- [ ] Login/session/access-context verified.
- [ ] Direction smoke flow verified.
- [ ] Secretariat smoke flow verified.
- [ ] Teacher smoke flow verified.
- [ ] Critical academic read/write flows verified.
- [ ] Browser smoke on production.
- [ ] Roadmap and release evidence synchronized.

Only after this gate do we resume F3/F4/F5/F6 product homologation.

## Non-goals

R0 does not introduce new dashboards, new business entities, alternative authorization systems, client-side business rules, broad service-role access, or UI duplication.
