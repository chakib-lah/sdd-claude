---
description: Scaffold a Node.js service from the active SDD spec
---

# /node-service

Generates the service (business logic) from the plan's Technical design (services), honoring the behavioral requirements and ACs of `spec.md`.

## Prerequisites

- `spec.md` and `plan.md` with `status: approved`

## Generates

1. `<name>.service.ts` — business logic, injectable, testable without HTTP
2. `<name>.service.test.ts` — unit tests with mocks

## Rules applied

- One responsibility per service
- Dependencies injected via constructor (no internal `new`)
- Never access Express `req`/`res` inside a service
- Unit tests without a database (mocked repositories)
