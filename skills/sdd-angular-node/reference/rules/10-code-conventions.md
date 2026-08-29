---
description: Layer 2 — Angular + Node.js/Express/TypeScript code conventions
---

# Code conventions — Angular + Node.js

> **Layer 2 — Specific to the Angular + Node.js stack.**  
> Adapt according to the versions detected in Phase 1.

---

## TypeScript — Rules common to frontend and backend

- `strict: true` in every `tsconfig.json`
- Never `any` — use `unknown` + narrowing when the type is uncertain
- Never an unjustified `as <Type>`
- `readonly` on properties that must not be mutated
- Interfaces for data models, types for unions

---

## Node.js / Express backend

### Recommended structure

```
backend/src/
├── routes/          ← Route definitions (thin, delegate to controllers)
├── controllers/     ← Orchestration, no business logic
├── services/        ← Business logic, unit-testable
├── repositories/    ← Data access (if ORM)
├── middleware/      ← Auth, validation, errors, logging
├── types/           ← TypeScript types shared with the frontend (or link to packages/shared)
└── utils/           ← Pure utility functions
```

### Conventions

- Thin controllers: no business logic — orchestration only
- Services: single responsibility, injectable, testable without HTTP
- Input validation: Zod on all bodies, params, query strings
- Global error middleware registered last in Express: `app.use(errorHandler)`
- Environment variables validated at startup with Zod or `envalid`
- Naming: `user.service.ts`, `user.controller.ts`, `user.routes.ts`, `user.repository.ts`

### Error handling

```typescript
// Centralized error middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof ValidationError) {
    return res.status(422).json({ message: err.message, code: 'VALIDATION_ERROR', violations: err.violations });
  }
  if (err instanceof NotFoundError) {
    return res.status(404).json({ message: err.message, code: 'NOT_FOUND' });
  }
  console.error(err);
  return res.status(500).json({ message: 'An error occurred', code: 'INTERNAL_ERROR' });
});
```

---

## Angular frontend

See `angular-conventions.md` for full details.

In summary:
- Standalone components + `OnPush` by default
- Signals for local state, RxJS for asynchronous streams
- `inject()` for dependency injection
- HTTP only in `*ApiService` services
- `takeUntilDestroyed()` systematically on subscriptions
- Never `any` on `HttpClient` responses

---

## Anti-patterns to ban

### Frontend (Angular)
- ❌ `console.log` left in the code
- ❌ `any` — use `unknown` if truly unknown (HttpClient responses included)
- ❌ Subscribe without `takeUntilDestroyed()` or the `async` pipe (memory leak)
- ❌ Direct state mutation (without `.update()` or spread)
- ❌ Direct `document.querySelector` (go through an Angular service or `Renderer2`)

### Backend (Node.js)
- ❌ `console.log` left in the code (use the project logger)
- ❌ Endpoint without Zod validation on its inputs
- ❌ `try/catch` without a call to `next(err)` (errors must reach the error middleware)
- ❌ Environment variables used without prior validation
