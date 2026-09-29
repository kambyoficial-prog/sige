# 46 — SIGE Supabase environment

## Remote project

- Project: `SIGE`
- Project ref: `pfnxvhwpbvlshjjdwbtj`
- Region: `eu-west-1`
- PostgreSQL: 17.6
- API URL: `https://pfnxvhwpbvlshjjdwbtj.supabase.co`

The repository is linked through:

`supabase/config.toml`

No service-role/secret key is committed.

## Migration state

All migrations present in `supabase/migrations/` through `20260929240100_teacher_roster_read_boundary` are applied to the remote SIGE project.

The database contains the expected operational tables, including:

- academic structure;
- enrollment;
- curriculum;
- assessment;
- finance;
- calendar/timetable;
- class sessions;
- attendance;
- audit;
- academic result ledger.

## Runtime verification

The remote database was queried directly.

Verified:

- F5 command functions exist;
- schedule conflict indexes exist;
- class-session functions exist;
- class-session read projections exist;
- session projections use `security_invoker=true`;
- authenticated has no direct INSERT/UPDATE/DELETE grant on `class_sessions`;
- authenticated has no direct INSERT/UPDATE/DELETE grant on `attendance_records`.

The database therefore contains the F5 command boundary expected by the application.

## Security gate

Supabase Security Advisor currently reports one critical finding:

- `public.curriculum_areas` has RLS disabled;
- `public.curriculum_choice_groups` has RLS disabled.

Both tables already have read policies. The repository now contains:

`20260929240200_enable_curriculum_rls.sql`

which enables RLS on those two tables.

**This migration has intentionally not been applied yet.** The Supabase advisor requires an explicit decision before enabling RLS because enabling RLS without appropriate policies would block access. In this schema, the policies already exist, but the final production/security gate should still be explicitly approved.

The security remediation SQL is:

```sql
alter table public.curriculum_areas enable row level security;
alter table public.curriculum_choice_groups enable row level security;
```

## Performance Advisor

The fresh database reports many unused indexes. This is expected immediately after provisioning an empty database and must not be interpreted as evidence that those indexes should be removed.

The advisor also reports multiple permissive SELECT policies in several tables. These should be consolidated only after measuring actual query plans and confirming that the policies have equivalent semantics. Blind policy deletion would risk changing authorization behavior.

## Testing limitation

The repository's pgTAP test files were inspected, but pgTAP is not installed in the remote project. The equivalent F5 structural assertions were executed directly through SQL and all returned true.

The test extension has not been installed merely for production verification.

## Environment separation

The previously connected Supabase project was a Kamby/marketplace database and was not used for SIGE. The SIGE project is now isolated under its own project ref.

Frontend configuration expects:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

The publishable key is appropriate for browser use; service-role credentials must remain server-side and must never be committed.
