---
description: Generates Node.js tests from the acceptance criteria in spec.md
---

# /node-test

Generates the backend tests (unit + integration) from the acceptance criteria in `spec.md`.

## Prerequisites

- `spec.md` with `status: approved`

## Generates

- Service unit tests: one `it()` per business behavior
- Supertest integration tests: one `it()` per API-type AC
- Coverage of error cases (422, 401, 404)

## Rules applied

- `describe` + `it` readable as sentences
- Each test: arrange → act → assert
- No test without an assertion
