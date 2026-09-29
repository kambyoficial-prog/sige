# SIGE

Sistema Integrado de Gestão Escolar.

SIGE is an operational school-management platform. Phase one targets Ensino Secundário while the architecture remains prepared for Centro Infantil and Ensino Primário.

## Engineering principles

- Domain truth before UI convenience.
- Historical records are preserved; state changes are explicit.
- Person, account, role, enrollment, class placement and teacher assignment are distinct concepts.
- Academic calculations are deterministic and versioned.
- Financial obligations and payments are separate events.
- Authorization is enforced server-side and at the database boundary.
- No production credentials or secrets are committed.
- Important business rules are testable without the UI.

## Repository

- `apps/web`: Next.js application.
- `packages/domain`: framework-independent domain model and rules.
- `packages/database`: database boundary.
- `packages/auth`: authentication/authorization boundary.
- `packages/config`: shared configuration.
- `supabase/`: migrations, seeds and database tests.
- `docs/`: architecture and decisions.
- `docs/architecture/37-frontend-product-architecture-and-design-system.md`: frontend product/design baseline.
- `docs/architecture/38-implementation-roadmap.md`: full execution roadmap and release gates.
- `docs/architecture/39-frontend-foundation-closeout.md`: F0 implementation decisions and verification gate.

## Development

Requirements: Node.js 22.14+ and pnpm.

```bash
pnpm install
pnpm dev
```

Remote Supabase is intentionally not connected at this foundation stage.
