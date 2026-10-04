# ulik.no

This comparison branch uses Gleam 1.18.1 + Lustre 5.7.1 (JavaScript target), Vite,
Bun, Biome, Gleeunit, Vitest and Playwright.

## Commands

- `bun install --frozen-lockfile`
- `bun run dev`
- `bun run check`
- `bun run lint`
- `bun run test`
- `bun run build`
- `bun run test:e2e`

Run all checks before completion; UI changes also require browser tests.

## Design

Keep pure state and UI in `src/*.gleam` and `src/pages/*.gleam`. Prefer meaningful
union types, small explicit functions and readable views. Browser-only APIs belong
in `src/browser/` with typed direct bindings in `src/*_ffi.mjs`. Do not introduce
an untyped command bus. Keep animation state with its canvas/WebGL renderer.

Preserve keyboard/touch accessibility, reduced-motion preferences, cleanup and
stale-callback handling. Rendered text must remain safe. Do not transmit user input
from the local tools. Keep no-JavaScript HTML and navigation working by rendering
the same Lustre views at build time.

Gleam compiler output lives in `build/`; distributable static files live in `dist/`.
Neither belongs in Git. Preserve isolated Firebase PR previews and the distinction
between beta-on-main and production-on-release. Do not merge or release without
explicit authorization.
