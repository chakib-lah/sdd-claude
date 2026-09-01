---
description: Layer 2 — brownfield rules to avoid breaking existing API contracts and components
---

# Migration Guard — Angular + Node.js (Brownfield)

> **Layer 2 — Active in brownfield mode only.**

---

## Main rule

Before modifying an existing endpoint, identify all of its consumers on the Angular side.

---

## API breaking changes

- Adding a response field → **non-breaking** ✅
- Renaming a field → **breaking** ❌ — versioning or coordinated migration
- Removing a field → **breaking** ❌
- Changing a field's type → **breaking** ❌

Procedure for a breaking change:
1. Document it in `docs/specs/<feature>/breaking-changes.md`
2. Keep the old endpoint as `@deprecated` during a transition period
3. Coordinate the Angular update before removing the old one

---

## Angular breaking changes

- Adding an optional `@Input()` → **non-breaking** ✅
- Renaming or removing an `@Input()` → **breaking** ❌
- Changing the `@Output()` contract → **breaking** ❌

Document in `docs/specs/<feature>/breaking-changes.md`.

---

## `/retro-spec` in brownfield

Before modifying a complex existing module, run `/retro-spec` to generate a retrospective spec. This makes it possible to understand the original intent before making changes.
