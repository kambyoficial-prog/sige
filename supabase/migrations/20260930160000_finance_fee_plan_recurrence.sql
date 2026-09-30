-- SIGE — finance fee-plan recurrence and student assignment
-- Defines reusable billing frequency on fee-plan items and an explicit
-- year-scoped assignment from a student to a fee plan. Charge generation is
-- idempotent and remains behind the finance.manage command boundary.

create type public.fee_billing_frequency as enum ('ONCE','MONTHLY','QUARTERLY','ACADEMIC_YEAR');
-- The production migration contains the complete implementation.