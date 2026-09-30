# 53 — F3/F4 runtime verification

Date: 2026-09-30

## Purpose

Record verification against the authoritative SIGE Supabase project after R0. This document does not replace authenticated browser smoke; it records database/application-boundary evidence only.

## Authoritative environment

- Supabase project: `pfnxvhwpbvlshjjdwbtj`
- PostgreSQL: 17.6
- RLS is enabled on the critical F3/F4 relations.
- Current migration history includes `enable_curriculum_rls`, `remove_duplicate_enrollment_index` and `r0_stabilization_boundaries_v2`.

## F3 — People and enrollment

Current DEMO cardinalities:

- students: 6
- student_enrollments: 6
- student_registrations: 6
- class_placements: 6

The canonical command boundary exists for:

- `register_student`
- `create_guardian`
- `enroll_student`
- `place_student_in_class`
- `transfer_student_class`

The student directory and enrollment directory are server-side query surfaces. The authenticated application tree is explicitly dynamic because these surfaces depend on request/session cookies.

The `student_enrollments` read policy no longer derives teacher access through a recursive query against `student_enrollments`.

## F4 — Academic structure

Current DEMO cardinalities:

- class_groups: 3
- course_offerings: 24
- teacher_assignments: 24
- student_course_participations: 48

The canonical command boundary exists for:

- `create_class_group`
- `update_class_group`
- `generate_class_offerings`
- `assign_teacher_to_offering`
- `assign_class_group_director`

The read projections `class_group_directory` and `course_offering_directory` exist and are read-only views. Current projection cardinalities are 3 and 24 respectively.

The curriculum security gap previously documented is no longer present in the authoritative database:

- `curriculum_areas`: RLS enabled, policies present.
- `curriculum_choice_groups`: RLS enabled, policies present.

## Integrity position

No test command mutated DEMO records during this verification. Verification used read-only PostgreSQL inspection.

The implementation continues to preserve these boundaries:

`Person → Student → Annual enrollment → Class placement → Course participation`

and:

`Curriculum → Course offering → Teacher assignment`

No UI-level calculation or client-side authorization was introduced.

## Remaining Gate B evidence

The remaining verification is authenticated browser execution for Direction, Secretariat and Teacher. It must exercise the real session and permission context rather than infer authorization from a successful build.

Until that browser evidence exists, F3/F4 remain implemented and database-verified, but Gate B is not declared fully closed.
