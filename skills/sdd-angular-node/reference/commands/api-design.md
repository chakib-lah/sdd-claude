---
description: Generates or updates the OpenAPI contract from the API contract designed in plan.md
---

# /api-design

Generates or updates the `docs/api/openapi.yaml` file from the API contract designed in `plan.md` (Technical design → endpoints).

## Prerequisites

- `plan.md` with `status: approved` (and the approved `spec.md` behind it)
- The endpoint contract described in the plan's Technical design (method, route, payloads, response, HTTP codes)

## Generates / updates

`docs/api/openapi.yaml` with the new endpoint in OpenAPI 3.x format.

## After generation

```
💡 Next steps:
- Regenerate Angular types: npm run api:sync
- Verify sync: /contract-check
```
