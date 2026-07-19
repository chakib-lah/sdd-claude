---
description: Generates or updates the OpenAPI contract from the "API Contract" section of spec.md
---

# /api-design

Generates or updates the `docs/api/openapi.yaml` file from the "API Contract" section of `spec.md`.

## Prerequisites

- `spec.md` with `status: approved`
- "API Contract" section filled in

## Generates / updates

`docs/api/openapi.yaml` with the new endpoint in OpenAPI 3.x format.

## After generation

```
💡 Next steps:
- Regenerate Angular types: npm run api:sync
- Verify sync: /contract-check
```
