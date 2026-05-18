## Project Configuration

- **Language**: TypeScript
- **Package Manager**: bun
- **Add-ons**: none

---

# AGENTS.md

## Project Overview

This project uses:

- SvelteKit
- Svelte 5
- TypeScript
- Bun
- Vite
- Biome
- Vitest
- Playwright

Prefer modern, minimal and maintainable solutions.

---

# Development Commands

## Install

```bash
bun install
```

## Development

```bash
bun run dev
```

## Type Checking

```bash
bun run check
```

## Lint

```bash
bun run lint
```

## Format

```bash
bun run format
```

## Unit Tests

```bash
bun run test
```

## E2E Tests

```bash
bunx playwright test
```

## Production Build

```bash
bun run build
```

---

# General Rules

- Use TypeScript everywhere.
- Prefer explicit types for exported APIs.
- Avoid `any`.
- Keep files small and focused.
- Do not introduce unnecessary abstractions.
- Do not add dependencies unless clearly justified.
- Prefer composition over inheritance.
- Prefer pure functions where possible.
- Prefer readability over cleverness.
- Keep diffs minimal.
- Avoid rewriting unrelated code.

---

# Svelte Rules

## Use Svelte 5 Patterns

- Prefer Svelte 5 runes.
- Avoid legacy `$:` reactive syntax unless necessary.
- Prefer derived state over manual synchronization.
- Prefer explicit effects.
- Avoid unnecessary reactive state.

## Components

- Keep components focused on one responsibility.
- Prefer props over global state.
- Avoid deeply nested component trees.
- Extract reusable UI into `src/lib/components`.
- Avoid overly generic UI abstractions.

## State Management

- Use component-local state first.
- Use stores only when state must be shared.
- Avoid global stores for temporary UI state.
- Keep state ownership clear.

## Data Fetching

- Prefer SvelteKit `load` functions.
- Fetch on the server when possible.
- Avoid direct API fetching inside components unless UI-local.
- Keep server-only logic in server files.

---

# Project Structure

## Routes

Route-specific code belongs close to the route.

Example:

```text
src/routes/users/
  +page.svelte
  +page.ts
  components/
```

## Shared Code

Shared reusable code belongs in:

```text
src/lib/
```

Suggested structure:

```text
src/lib/
  components/
  server/
  stores/
  types/
  utils/
```

---

# TypeScript Rules

- Prefer `type` over `interface` unless extension is needed.
- Avoid type assertions unless unavoidable.
- Use discriminated unions where appropriate.
- Keep types close to usage unless broadly shared.
- Export explicit public types.

---

# Styling

- Prefer scoped component styles.
- Avoid global CSS unless necessary.
- Prefer CSS variables for theming.
- Keep styling simple and maintainable.
- Avoid heavy CSS frameworks unless justified.

---

# Forms

- Prefer progressive enhancement.
- Validate on both client and server.
- Use zod for schema validation.
- Keep form logic explicit and readable.

---

# API Rules

- Validate all external input.
- Never trust client-side validation alone.
- Keep API responses typed.
- Handle loading and error states explicitly.
- Prefer small focused endpoints.

---

# Testing Rules

## Unit Tests

Use Vitest for:

- business logic
- utility functions
- data transformations
- complex component behavior

## E2E Tests

Use Playwright for:

- routing
- forms
- authentication
- critical user flows
- regression testing

---

# Validation Requirements

Before completing any task, always run:

```bash
bun run check
bun run lint
bun run test
bun run build
```

For UI or routing changes, also run:

```bash
bunx playwright test
```

Do not consider work complete if commands fail.

---

# Dependency Guidelines

Preferred libraries:

- zod
- @tanstack/svelte-query

Avoid adding:

- large utility libraries
- unnecessary state frameworks
- duplicate tooling
- deprecated packages

---

# Performance

- Avoid unnecessary reactivity.
- Avoid unnecessary client-side rendering.
- Lazy load heavy features when appropriate.
- Prefer simple solutions over premature optimization.
- Minimize unnecessary rerenders.

---

# Accessibility

- Prefer semantic HTML.
- Ensure keyboard accessibility.
- Use proper labels for forms.
- Avoid inaccessible custom controls.
- Ensure sufficient contrast.
- Prefer native elements over recreated controls.

---

# Security

- Validate all external input.
- Never expose secrets to the client.
- Keep environment variables server-only unless public.
- Sanitize untrusted content.
- Avoid unsafe HTML rendering.

---

# Agent Behavior

- Do not rewrite unrelated code.
- Preserve existing architecture unless explicitly changing it.
- Prefer incremental refactoring over large rewrites.
- Explain non-trivial changes briefly.
- Ask before introducing major structural changes.
- Prefer consistency with existing patterns.
- Avoid speculative abstractions.
- Avoid placeholder implementations unless requested.

---

# Git Guidelines

- Keep commits focused and small.
- Avoid mixing refactors with feature changes.
- Preserve existing formatting conventions.
- Do not modify generated files unless required.

---

# Documentation

- Document non-obvious decisions.
- Keep README updates concise.
- Prefer examples over long explanations.
- Keep comments focused on intent, not mechanics.