# 41 — Operational frontend primitives

## Status
F2 implementation — 2026-09-29.

## Principle

The primitive layer exists to prevent every module from inventing its own table, form, error, search or confirmation behavior. It is intentionally small. A primitive is admitted only when it represents a repeated operational pattern.

## Implemented

- Button;
- Input;
- Label;
- Textarea;
- FormField;
- Badge;
- Alert;
- Skeleton/loading state;
- EmptyState;
- PageHeader;
- DataTable using TanStack Table;
- SearchInput with URL query state;
- Pagination;
- native accessible confirmation dialog;
- centralized application error presentation;
- Sonner transient feedback.

## URL state

Search state belongs in the URL when it changes the dataset or is useful to reproduce/share a view. Ephemeral UI state stays local. No global client store is introduced.

## Data tables

TanStack Table is headless and server-side friendly; the markup remains owned by SIGE. The first proof surface is the authenticated profile/access page using real current_access_context() data.

## Errors

Database/application error codes are converted to Portuguese operational messages in lib/sige/presentation.ts. Raw database messages, hints and SQL details must never become user-facing copy.

## Forms

React Hook Form owns client form state. Zod owns client input shape/validation. Neither library owns domain rules: authoritative validation remains in commands/Postgres.

## Explicit non-goals

No generic dashboard widget framework, no global Zustand/Redux store, no optimistic mutation framework, no second table library and no second form library.

## Verification gate

Dependency installation, typecheck, lint and build remain pending in a network-capable CI environment. Browser verification follows after the first successful build.
