# 50 — F8 Reporting and Documents

## Reporting architecture

Reports are projections over domain truth. The reporting UI does not calculate authoritative business numbers.

Current read models:

- `report_student_demographics`
- `report_enrollment_status`
- `report_enrollment_grade`
- `report_class_capacity`
- `report_finance_summary`
- `report_academic_outcomes`

All use `security_invoker=true` so school-level RLS remains authoritative.

## Required school indicators

The first reporting surface covers:

- M/F student distribution;
- enrollment by academic year;
- enrollment by grade;
- enrollment status;
- class occupancy/capacity;
- published academic outcomes;
- financial obligations and confirmed allocations.

The architecture leaves room for explicit event/episode reports for:

- desistências;
- anulações;
- transferências;
- matrícula inicial;
- infantil.

These should be added from dedicated domain events/status transitions rather than inferred from names or mutable UI state.

## Financial reporting

Financial totals are calculated in separate charge/payment aggregations. A direct join between charges and payment allocations must not multiply the charge amount when a charge has multiple allocations.

The report therefore follows the same invariant as `student_financial_balances`: charges are aggregated independently from payment allocations.

## Temporal semantics

Every annual report is scoped by `academic_year_id`. Current demographic counts remain current-student projections; annual enrollment metrics are year-scoped.

A future export layer must carry:

- report definition/version;
- school;
- academic year;
- generated timestamp;
- filters;
- source projection/version.

This makes exported documents reproducible and auditable.

## Security

No reporting view bypasses RLS. Reports are read-only and have no command mutation path.

## Verification

The SIGE database was checked directly for the six reporting projections and their authenticated SELECT grants. Structural assertions are committed in `supabase/tests/0036_f8_reporting_read_models.sql`.

The remote environment does not provide pgTAP; these assertions therefore do not claim remote pgTAP execution.
