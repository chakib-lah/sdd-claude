---
description: Layer 2 — Angular ↔ Node.js API contracts
---

# API Contracts — Angular ↔ Node.js

> **Layer 2 — Specific to the Angular/Node.js integration.**

---

## Guiding principle

> The API contract is defined in `spec.md` BEFORE implementation on both sides.  
> Shared types are defined once — never duplicated.

---

## Uniform error format

Every error returns the same format:

```json
{
  "message": "Validation failed",
  "code": "VALIDATION_ERROR",
  "violations": [
    { "field": "email", "message": "Invalid email format" }
  ]
}
```

Strict HTTP codes: 200, 201, 204, 400, 401, 403, 404, 409, 422, 500.

---

## Shared types

### Option A — Shared package (monorepo)

```
packages/shared/
└── types/
    ├── user.types.ts
    └── index.ts
```

```typescript
// packages/shared/types/user.types.ts
export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly createdAt: string;
}

export interface CreateUserRequest {
  readonly email: string;
  readonly password: string;
}
```

```typescript
// Angular consumes
import { UserResponse, CreateUserRequest } from '@shared/types';

// Node.js consumes
import { UserResponse, CreateUserRequest } from '../../packages/shared/types';
```

### Option B — Separate repos

The backend exposes an OpenAPI spec. The frontend generates types from that spec:

```bash
cd frontend
npm run api:sync   # calls openapi-generator-cli
```

---

## `/contract-check` command

Run `/contract-check` to detect Angular/Node.js drift:
- `any` types on `HttpClient` calls
- Endpoints not covered by types on the Angular side
- Untyped response fields

---

## Anti-patterns

- ❌ API response types duplicated between Angular and the backend
- ❌ `any` on `HttpClient` responses
- ❌ Error format differing across endpoints
- ❌ Implementing an endpoint without a contract in spec.md
