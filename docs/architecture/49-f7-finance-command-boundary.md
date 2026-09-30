# 49 — F7 Finance: command boundary and operational model

## Decision

Finance is a transactional domain, not a set of mutable balance fields.

Source of truth:

- obligations: `charges`;
- adjustments: `charge_adjustments`;
- payments: `payments`;
- settlement: `payment_allocations`;
- reversals: `payment_reversals`;
- receipts: `receipts`;
- derived balance: financial projections.

A balance is never written by the UI.

## Operational boundary

Authenticated users cannot directly INSERT/UPDATE/DELETE:

- fee types;
- fee plans/items;
- transport services;
- student services;
- charges;
- charge adjustments.

Mutations use idempotent, audited command functions:

- `create_fee_type`
- `create_fee_plan`
- `add_fee_plan_item`
- `create_transport_service`
- `assign_student_transport`
- `create_charge`
- `adjust_charge`
- `record_payment`
- `confirm_payment`
- `allocate_payment`
- `reverse_payment`
- `issue_receipt`

## Transport

Transport is optional.

A student may have no transport service. When assigned, the service is explicitly linked to the academic year and student context. Route and stop are operational attributes; transport charges remain ordinary financial obligations.

## Read model

The application reads:

- `finance_charge_directory`
- `finance_payment_directory`
- `finance_balance_directory`
- `student_financial_balances`

All finance projections use `security_invoker=true` and depend on RLS of their underlying tables.

## Year scoping

Charges belong to an academic year. Payments do not: a payment is a financial transaction that may be allocated to obligations from a historical academic year.

Closed academic years reject creation/modification of year-bound obligations and services. Payment correction remains an explicit financial command and is audited.

## Failure modes covered

- cross-school student/payment/charge contexts;
- fee configuration crossing school/year boundaries;
- allocation exceeding payment or charge capacity;
- payment allocation before confirmation;
- reversal of non-confirmed payments;
- receipt issuance for non-confirmed payments;
- duplicate command submission;
- direct authenticated financial writes;
- projection reads blocked by incomplete RLS boundaries.

## Verification

The authorized SIGE database was checked directly for:

- command function existence;
- finance RLS policies;
- absence of direct authenticated mutation grants;
- finance projection existence;
- balance projection path.

The remote project does not provide pgTAP; repository tests therefore include structural SQL assertions rather than claiming remote pgTAP execution.

## Non-goals

F7 does not introduce:

- accounting general ledger;
- payroll;
- tax calculation;
- external payment gateway integration;
- automatic debt collection;
- mandatory transport.

Those are separate domains and must not be mixed into school receivables without explicit requirements.


## Student payment journey

The student-facing financial flow is read-only until a school employee records a payment:

1. The school configures payment instructions for the academic year: bank, account holder, account number/NIB/IBAN, branch and reference instructions.
2. The SIGE exposes each student's annual charges as individual obligations. A monthly tuition charge is its own charge record, not a mutable balance label.
3. The student portal shows the academic year, each obligation, due date, amount, paid amount and remaining amount, plus the school's current payment instructions.
4. The student/guardian pays externally (for example at the configured bank) and brings the bank proof to the secretariat.
5. Secretariat records the payment as PENDING, including method, paid date, external reference and notes.
6. Secretariat verifies the proof and confirms the payment. Only CONFIRMED payments can be allocated.
7. The confirmed payment is allocated to the exact obligation(s). This is what changes the student's outstanding balance.
8. SIGE issues the official receipt only after confirmation. The receipt is printable and contains the student, payment, allocated obligation, amount, date and receipt number.
9. Physical stamping/signature remains an optional school procedure; it is not represented as a fake digital payment state.

The student never marks a charge as paid and never confirms their own payment. This preserves separation of duties and auditability.

### Inscription versus monthly tuition

The same financial lifecycle can represent both the initial enrollment/registration fee and recurring tuition. They remain distinct fee_type/charge instances, allowing the school to configure whether a fee is one-time, monthly or another defined schedule without turning the student's portal into a collection of ad-hoc fields.


## Payment proof evidence boundary

Bank/transfer/card payments are not confirmable merely because an operator clicked the confirmation action.

The evidence lifecycle is:

`UPLOADING -> READY -> VERIFIED`
or
`READY -> REJECTED`.

A rejected proof is not re-verified. A new proof is uploaded instead. This keeps each evidence artifact immutable in its verification history.

### Storage

Payment proofs use a dedicated private Supabase Storage bucket:

- bucket: `payment-proofs`;
- allowed types: PDF, JPEG, PNG;
- maximum object size: 10 MiB;
- object path: `payments/<payment_id>/<proof_id>-<sanitized_filename>`.

The bucket is private. Supabase's current Storage guidance states that private buckets are protected by Storage RLS and should be accessed through authenticated downloads or time-limited signed URLs. Uploads are also controlled by `storage.objects` RLS.

The repository defines the bucket in `supabase/config.toml`. The production bucket must be provisioned through the Supabase Storage API/Dashboard or the project's bucket seeding process; the database migration deliberately does not mutate `storage.buckets` directly because Supabase documents the Storage metadata schema as read-only and recommends Storage API operations.

### Confirmation invariant

`confirm_payment` now enforces:

- CASH: may be confirmed by the authorized finance operator without a file;
- non-CASH: at least one `VERIFIED` payment proof is mandatory.

This is a database invariant, not a frontend convention.

### Receipt invariant

`issue_receipt` now additionally requires:

- payment status = `CONFIRMED`;
- total allocated amount = payment amount.

Therefore the backend cannot issue a receipt for an incompletely allocated payment even if a client bypasses the UI.

### Audit

The following events are recorded in `audit_events`:

- `CREATE_PAYMENT_PROOF`;
- `FINALIZE_PAYMENT_PROOF`;
- `VERIFY_PAYMENT_PROOF`;
- `CONFIRM_PAYMENT`;
- `ISSUE_RECEIPT`.

The proof table itself is not writable through generic authenticated CRUD. Mutations cross explicit command functions.

### Operational journey

1. Secretariat records the bank payment as `PENDING`.
2. Secretariat attaches the bank proof.
3. SIGE uploads the document to the private bucket and finalizes its evidence record.
4. Secretariat opens the private proof through a short-lived signed URL.
5. Secretariat validates or rejects the proof.
6. Only a verified proof permits confirmation for non-CASH payments.
7. The confirmed amount is allocated to one or more concrete charges.
8. Only full allocation permits receipt issuance.
9. The receipt is generated with a server-side sequential number and remains auditable.

This separates **evidence**, **verification**, **payment confirmation**, **allocation**, and **receipt issuance** instead of collapsing them into one mutable payment flag.
