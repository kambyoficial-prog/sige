# 39 — Frontend foundation closeout

## Status
F0 implementation baseline — 2026-09-29.

## Research decisions

The foundation follows the current shadcn guidance for Next.js, Tailwind v4, semantic CSS variables and dark mode. shadcn currently recommends CSS variables for semantic tokens and `next-themes` for Next.js dark mode. Sonner is the supported direction for transient toast feedback.

Apple Human Interface Guidelines were used as a reference for layout discipline, familiar controls, hierarchy and the principle that branding should defer to useful content. No Apple visual asset or protected interface is copied.

## Implemented

- Tailwind CSS 4.3.x and PostCSS integration.
- shadcn registry configuration with `base-nova`, neutral semantic tokens and Lucide.
- Light/dark/system theme provider.
- Semantic OKLCH color tokens.
- Consistent radius, focus and typography baseline.
- Reduced-motion baseline.
- `cn()` class composition utility.
- Button primitive based on the shadcn composition model.
- Sonner provider.
- Typed capability-aware navigation model.
- Responsive application shell foundation.
- Global loading, error and not-found states.
- Portuguese (Mozambique) document language.

## Deliberate design decisions

### Neutral visual base
The product does not start with a saturated brand color. The operational UI needs hierarchy first. A brand accent can be introduced once the school's identity and product branding are defined.

### System font stack
The web uses an OS-native sans stack to preserve platform-appropriate rendering and reduce unnecessary font infrastructure at this stage.

### Semantic tokens
Components reference semantic roles (`background`, `foreground`, `primary`, `muted`, `border`, `ring`) rather than raw color values. This keeps light/dark behavior and future brand refinement centralized.

### Navigation
Navigation is defined once as typed configuration and later filtered by the real access context. A screen must not duplicate the same menu structure locally.

### Mobile
The shell provides a compact navigation surface without introducing a second navigation taxonomy. The mobile representation will be replaced by the full shadcn sidebar/drawer primitives when the authenticated shell is implemented.

## Known verification gate

Dependencies were updated in the repository, but the execution environment used for this work cannot reach GitHub/npm from its local container. Therefore no claim is made that `pnpm install`, `pnpm typecheck`, `pnpm lint` or `pnpm build` has passed yet.

The next CI-capable environment must:

1. install dependencies and generate `pnpm-lock.yaml`;
2. run typecheck, lint and production build;
3. fix any version/API incompatibilities discovered by the real toolchain;
4. run browser verification against the resulting app.

This is a verification gate, not a known product defect.

## Next block

F1 — Authentication & access context. The shell becomes real only when its school/user/role context is populated by the existing `current_access_context()` contract and protected routes are enforced server-side.
