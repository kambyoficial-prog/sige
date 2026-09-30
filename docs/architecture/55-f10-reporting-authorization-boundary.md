# F10 — Reporting Authorization Boundary

## Decision

Reporting is an explicit application capability, not an incidental consequence of being able to read operational records.

The SIGE therefore introduces:

- `reports.read` for institutional reporting;
- Direction and Pedagogical Direction receive `reports.read`;
- Secretariat does not receive `reports.read`;
- financial reporting additionally requires `finance.read` or `finance.manage`;
- aggregate report views are no longer directly exposed through the Data API to `authenticated` or `anon`;
- application reads and CSV exports use the controlled `get_report_rows(report, academic_year_id)` RPC.

## Why the previous boundary was insufficient

The report projections were correctly marked `security_invoker=true`, which preserved the RLS of their source tables. That was useful for row-level data protection, but it was not sufficient to express the product rule that Secretariat may operate enrollment and school operations without consuming institutional reports.

A user can have legitimate access to student/enrollment records while still not being a report consumer. Authorization must therefore exist at the report capability boundary.

Supabase documentation confirms that grants and RLS are separate controls, and that exposed views/functions require explicit authorization. Security-invoker views preserve underlying RLS, while restricted functions can provide a controlled application boundary. Sources:

- Supabase RLS and grants: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase views: https://supabase.com/docs/guides/database/views
- PostgreSQL SECURITY DEFINER: https://www.postgresql.org/docs/current/sql-createfunction.html

## RPC security model

`get_report_rows` is a read boundary implemented as a SECURITY DEFINER function.

Invariants:

1. caller must be authenticated;
2. report name is an explicit allow-list;
3. general reports require `reports.read`;
4. financial reports require `finance.read` or `finance.manage`;
5. function uses `set search_path=''`;
6. public execution is revoked;
7. only `authenticated` receives EXECUTE;
8. report views themselves have direct SELECT revoked from `anon` and `authenticated`.

The function returns aggregate/read-model data only; it does not mutate domain state.

## Application boundary

The page, navigation and CSV export all enforce the same capability:

- page: `reports.read`;
- navigation: `reports.read`;
- export: `reports.read`;
- finance report: additional finance permission.

The frontend check is UX and route protection. The database RPC remains the authoritative report access boundary.

## Verification

Before merge:

- migration syntax and object dependencies were executed against the live database inside an explicit transaction and rolled back;
- no production data was modified;
- F10 database invariants cover:
  - permission existence;
  - Direction and Pedagogical Direction access;
  - Secretariat denial;
  - absence of direct SELECT grants on report views;
  - SECURITY DEFINER + `auth.uid()` + pinned search path;
  - no anonymous function execution.

## Release gate

F10 is complete only after:

1. CI is green;
2. migration is applied to the production Supabase project;
3. application deployment containing the RPC-based report reads is READY;
4. authenticated browser smoke confirms Direction/Pedagogical Direction can open and export reports;
5. authenticated browser smoke confirms Secretariat receives `/acesso-negado` for direct report navigation/export;
6. financial report visibility is checked independently.

The current Vercel deployment-rate limit prevents steps 2–5 from being closed together safely. The PR remains isolated until deployment capacity is available.
