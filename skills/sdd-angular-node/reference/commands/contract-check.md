---
description: Verifies type synchronization between Angular and the Node.js backend
---

# /contract-check

Verifies that the Angular types are in sync with the backend's API contract.

## Prerequisites

- `spec.md` of the active feature
- Angular and backend code in place

## Checks

1. Every `HttpClient` call has an explicit type (no `any`)
2. Angular interfaces match the `packages/shared/` types or the OpenAPI spec
3. Response fields used in templates exist in the types
4. The error format handled on the Angular side matches the backend format

## Report

```
Contract Check — <FEATURE-ID>
──────────────────────────────
✅ Typed HttpClient : 4/4 calls
✅ Shared types     : in sync
❌ Missing field    : UserResponse.lastName used in template but absent from the type
⚠️  API error       : code 409 not handled on the Angular side

Actions:
1. Add lastName to UserResponse
2. Handle the 409 case in the error interceptor
```
