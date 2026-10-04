# Project guidance

ulik.no uses Elm 0.19.1, elm-watch, JavaScript browser adapters, Bun, Vite, Biome, Vitest, elm-test and Playwright.

## Commands

```sh
bun install
bun run dev
bun run check
bun run lint
bun run test
bun run build
bun run test:e2e
```

Run all checks before completing a change. Browser tests use the production build, including prerendered routes. Install Chromium with `bunx playwright install chromium` if necessary. Report any check that could not run; a focused check is not a complete pass.

## Architecture

- Elm owns routing, application state, validation and HTML/SVG views.
- Use union types for alternatives and states; use records for ordinary data.
- Keep pages in `src/elm/Pages/` with explicit `init`, `update`, `view` and `subscriptions`.
- Keep shared project metadata in `Projects.elm`.
- Keep exactly one outgoing and one incoming port in `Ports.elm` unless a specific need justifies more.
- Browser-only effects belong in `src/browser/`, using tagged `domain`/`action` messages. Elm must decode incoming values before using them.
- Every browser adapter must clean up listeners, timers, animation frames and resources in `dispose()`. Guard late asynchronous results after navigation.
- Keep code readable and focused. Avoid generic effect frameworks, unnecessary abstractions, dependencies or speculative features.
- Do not reintroduce a UI framework in JavaScript.

## UI and tests

Preserve Norwegian text, existing routes and accessible keyboard/touch controls. Respect reduced motion. Use semantic HTML and labeled native controls. Scope CSS by page class. Keep essential static content in Elm views so prerendering uses the same source.

Test repeated actions, interrupted flows and Back/Forward as well as the happy path. Use elm-test for Elm behavior, Vitest for browser-adapter algorithms and Playwright for integration. Mock permission prompts in automated media tests; never capture a real user's screen for testing without authorization.

## Deployment and security

Keep Firebase preview builds separated from deployment credentials. Preserve the existing beta/main and release/production targets. A request to create a PR does not authorize merging it or publishing a release. Never expose secrets in client code. Open new PRs as drafts unless directed otherwise.

Keep commits focused. Preserve unrelated user changes and do not weaken tests to hide regressions. Document non-obvious decisions briefly.
