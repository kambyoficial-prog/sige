# Auth runtime boundary — SSR, student login and first access

## Problem

Production exposed React error #441 because server-rendered paths reached
`createSupabaseAdminClient()` while the Vercel environment did not contain an
administrative Supabase key.

The React error was only the production rendering wrapper. The underlying
exception was `SUPABASE_ADMIN_ENV_NOT_CONFIGURED`.

## Decision

Normal authenticated application flow must not depend on a Supabase secret key.

Three boundaries were corrected:

1. **Authenticated layout**
   - reads `app_accounts.first_access_required` with the user's SSR client;
   - RLS policy permits only the row whose `auth_user_id = auth.uid()`;
   - no Admin API call is made during normal layout rendering.

2. **Sign-in**
   - institutional email login uses the normal Supabase Auth client;
   - student school-number login resolves the synthetic internal Auth identity
     through `resolve_student_login_email(text)`;
   - the resolver returns only the deterministic synthetic identity and does not
     require the Auth Admin API;
   - the password check remains Supabase Auth's responsibility.

3. **First access**
   - account state is read through user-scoped RLS;
   - password change uses the authenticated Auth client;
   - the transition `first_access_required=true -> false` is performed by
     `complete_first_access_account()`, a narrow authenticated RPC;
   - the RPC requires `auth.uid()` and pins `search_path`;
   - no direct UPDATE privilege is granted to authenticated users.

## Administrative boundary

Supabase Admin API remains reserved for genuine provisioning operations that
create/delete Auth users or otherwise require elevated Auth privileges.

Those operations are not part of page rendering or ordinary sign-in.

Supabase's current API-key guidance distinguishes publishable keys for
user-facing components from secret keys for controlled backend components.
See:
https://supabase.com/docs/guides/getting-started/api-keys

## Verification

- Live migration applied.
- First-access RPC: authenticated EXECUTE only; anonymous EXECUTE denied.
- Student login resolver: anonymous/authenticated EXECUTE; `search_path`
  pinned; SECURITY DEFINER.
- Authenticated account lifecycle test `0040` executed successfully.
- Production deployment for commit `71da08e70896480e83ddf3e5dee03a8e9fe4fd25`
  reached READY.
- Runtime logs for that deployment returned no errors.

## Release interpretation

React #441 is not considered fixed by suppressing the client error. The fix is
the removal of the server-side administrative dependency from the affected
render/authentication paths and verification against the production
deployment.
