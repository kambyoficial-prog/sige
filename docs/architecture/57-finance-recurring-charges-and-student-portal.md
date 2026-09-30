# Finance — fee plan recurrence and student payment portal

## Decision

SIGE does not hard-code school months in the UI. A financial plan is a reusable configuration, assigned explicitly to a student for an academic year.

fee_plan_items now carries billing frequency:

- ONCE
- MONTHLY
- QUARTERLY
- ACADEMIC_YEAR

A student_fee_plan_assignments record binds one active plan to one student/year. Only one active assignment is allowed per student and academic year.

## Charge generation

generate_student_fee_plan_charges derives occurrences from the academic-year boundaries and the assignment period. It is idempotent: re-running the command does not create duplicate charges for the same student, year, fee type and due date.

This keeps the financial ledger authoritative in charges; the portal is only a read model.

## Student journey

1. Student signs in.
2. Opens Meus pagamentos.
3. Sees the current academic year, obligations, due dates, amount paid and remaining balance.
4. Reads school-configured bank/payment instructions.
5. Pays outside SIGE according to the school's configured procedure.
6. Brings the external proof to the Secretariat.
7. Secretariat records the payment as PENDING.
8. Secretariat verifies the proof and confirms the payment.
9. The confirmed payment is allocated to the relevant charge(s).
10. SIGE issues the receipt.
11. The student can see the confirmed payment and receipt number in the portal.

The student never changes a charge or marks a payment as paid.

## Security boundary

The student portal uses get_student_financial_portal(), which resolves the authenticated student server-side and returns only that student's current-year financial context.

Financial mutations remain behind finance.manage command functions. The portal has no payment-write operation.

## Operational scheduling

Supabase Cron/pg_cron is suitable for scheduled reconciliation/generation, but the domain command remains idempotent so scheduling is an operational concern, not the source of truth.

## Next block

Complete the Secretariat payment-verification workbench:

- pending-payment queue;
- student/payment proof review;
- confirmation;
- allocation;
- receipt issuance;
- printable receipt;
- audit trail;
- authorization tests.
