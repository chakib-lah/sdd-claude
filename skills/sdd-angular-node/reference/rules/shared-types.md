---
description: Layer 2 — rules for TypeScript types shared between Angular and Node.js
---

# Shared types — Angular ↔ Node.js

> **Layer 2 — Rules for shared types.**

---

## Absolute rule

**A type is defined once.** Never duplicated between Angular and Node.js.

---

## Location

- Monorepo: `packages/shared/types/`
- Separate repos: types generated from the backend's OpenAPI spec

---

## Naming convention

| Type | Convention | Example |
|---|---|---|
| API response | `<Resource>Response` | `UserResponse` |
| Creation payload | `Create<Resource>Request` | `CreateUserRequest` |
| Update payload | `Update<Resource>Request` | `UpdateUserRequest` |
| Filter / query params | `<Resource>Filters` | `UserFilters` |

---

## Modification workflow

1. Modify the type in `packages/shared/types/`
2. Check backend-side compatibility (strict TypeScript)
3. Check Angular-side compatibility (strict TypeScript)
4. Both must compile without errors before committing
5. Commit: `refactor(<TICKET>): update <Type> shared type`

The PostToolUse hook on `packages/shared/` displays a reminder alert.

---

## Anti-patterns

- ❌ Redefining `UserResponse` in `frontend/src/app/models/user.model.ts`
- ❌ `any` types for API responses "temporarily"
- ❌ Copy-pasting an interface from one side to the other
