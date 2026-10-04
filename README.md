# ≠ ulik.no — Gleam + Lustre

An independent comparison implementation of the complete site, based on `main`.
The Elm alternative is PR #55; this branch is not stacked on it.

## Run

Install [Gleam 1.18.1](https://gleam.run/getting-started/installing/), Node.js, and Bun.
This project targets JavaScript; Erlang is not required locally.

```sh
bun install --frozen-lockfile
bun run dev
```

`dev` compiles Gleam, watches source changes, and starts Vite. `gleam.toml` and
`manifest.toml` pin the Gleam package graph; `bun.lock` pins JavaScript packages.

```sh
bun run check
bun run lint
bun run test
bun run build
bunx playwright install chromium
bun run test:e2e
```

## Read the implementation

- `src/ulik.gleam`: route and page union types, navigation, shell, and lifecycle.
- `src/pages/*.gleam`: each project's model, message union, update, and Lustre view.
- `src/projects.gleam`, `src/discovery.gleam`: typed catalog, filters and suggestions.
- `src/*_ffi.mjs`: explicit typed JavaScript bindings called from Gleam. No ports,
  serialized command bus, or compiled Elm is used.
- `src/browser/`: browser-only primitives: canvas/WebGL rendering, speech/audio,
  screen capture, local clipboard/downloads and the text-diff library.

Application state and HTML live in Gleam. The animation loops stay next to canvas
and Three.js so per-frame values do not travel through UI updates. Browser-resource
cleanup runs on navigation; stale page callbacks are rejected by route revision.

`src/pages/screen.gleam` is a short example of state variants and browser bindings.
`src/pages/illusions.gleam` shows a mostly pure view. `src/pages/morse.gleam` is the
larger example of timed interactions, scoring and history.

## Static HTML and deployment

The build uses Lustre's own `element.to_string` on the same views to prerender all
15 routes. Content and ordinary links work without JavaScript. Interactive canvas,
WebGL, speech and capture need JavaScript and browser support. Output is `dist/`;
Gleam's separate `build/` directory contains compiler artifacts only.

Client navigation keeps one application document, ignores repeated same-URL clicks,
and restores each history entry's scroll after the new page renders.

Firebase PR previews remain isolated channels on the `beta-ulik-no` site in the
`eidjord` project. Preview deployment receives only static artifacts on a fresh
runner. Pushes to `main` retain beta deployment; production still requires a
published release. This comparison PR does not merge or publish a release.

## Tests

Gleeunit covers routing, models, scoring, bounded configuration and views. Vitest
covers browser resource lifecycle and rendering engines. Playwright exercises all
nine projects, static/no-JS pages, keyboard/touch input, reduced motion, repeated
operations, cleanup, client navigation and Back/Forward scroll.

Speech synthesis and the screen-permission API are mocked in browser tests. Capture
tests use real canvas-backed `MediaStream`s after the mocked grant; they do not
verify an operating-system picker or a real speech voice.
