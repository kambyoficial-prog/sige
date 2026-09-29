# 40 — Authentication & access implementation

## Status
F1 implementation — 2026-09-29.

## Decisions

SIGE uses Supabase Auth with cookie-based SSR through @supabase/ssr. Next.js 16 uses proxy.ts; session refresh uses auth.getClaims(), which Supabase documents as the server-side method for verifying JWT claims. The server must never use a raw session from cookies as an authorization decision.

The application has two route classes: public /login and /acesso-negado; authenticated app/(app)/**.

The authenticated layout resolves current_access_context() on the server and derives navigation from returned permissions. Database authorization remains authoritative; frontend permissions are a rendering optimization and UX boundary, not a security boundary.

## Implemented

- login form with Zod + React Hook Form;
- generic invalid-credential response;
- server-side password sign-in;
- PKCE callback retained;
- root redirect based on verified claims;
- authenticated route group;
- current access context loaded server-side;
- access-denied state for authenticated accounts without active school membership;
- server-backed sign-out;
- multi-school accounts are not assigned an arbitrary school in the UI; a future explicit school-context contract is required before selection is added.

## Security properties

- no service-role key in browser code;
- getClaims() used for identity verification;
- backend/database authorization remains authoritative;
- no raw Supabase error is displayed to the user;
- invalid credentials do not reveal whether an email exists;
- authenticated pages cannot render without access context;
- inactive-school authorization is already blocked by the database authorization layer.

## Verification gate

Real Supabase authentication cannot be exercised until the authorized SIGE Supabase project is connected. The currently connected project is another product and is deliberately untouched.

Once connected, test at minimum: valid login, invalid credentials, expired session, sign-out, no school membership, inactive school, one membership, multiple memberships, direct access to protected routes and direct RPC authorization.
