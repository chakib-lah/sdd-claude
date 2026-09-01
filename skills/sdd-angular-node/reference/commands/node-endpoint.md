---
description: Scaffold a complete Node.js/Express endpoint from the active SDD spec
---

# /node-endpoint

Generates controller + route + middleware + integration tests from the API contract in `spec.md`.

## Prerequisites

- `spec.md` with `status: approved`
- "API Contract" section filled in with method, route, payload, response, HTTP codes

## Generates, in order

1. Zod schema for input validation
2. Controller with error handling (`try/catch → next(err)`)
3. Express route with auth middleware if required
4. Supertest integration test covering nominal and error cases

## Rules applied

- Thin controller: no business logic
- Zod validation before any operation
- Uniform error format (see `50-api-contracts.md`)
- Correct HTTP codes per `50-api-contracts.md`
