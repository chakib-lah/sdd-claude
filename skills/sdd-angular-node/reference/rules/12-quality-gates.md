---
description: Layer 2 — Angular + Node.js quality gates
---

# Quality Gates — Angular + Node.js

> **Layer 2 — Specific to the Angular + Node.js stack.**

---

## Node.js backend

```bash
# Lint
npx eslint src/ --ext .ts

# TypeScript check
npx tsc --noEmit

# Tests + coverage
npm test -- --coverage
```

Executable threshold — `coverageThreshold` in `jest.config.js` (or `coverage.thresholds`
in `vitest.config.ts`) makes the run itself fail below it:

```js
coverageThreshold: {
  global: { lines: 80, branches: 75, functions: 75, statements: 80 },
},
```

---

## Angular frontend

```bash
# Lint
npx eslint src/ --ext .ts

# TypeScript strict check
npx tsc --noEmit

# Production build (catches template errors)
ng build --configuration production

# Tests
ng test --watch=false --browsers=ChromeHeadless
```

---

## Global quality command (Makefile or npm script)

```makefile
quality:
	cd backend && npx eslint src/ --ext .ts
	cd backend && npx tsc --noEmit
	cd frontend && npx eslint src/ --ext .ts
	cd frontend && npx tsc --noEmit
	cd frontend && ng build --configuration production
```

---

## Forbidden markers before commit

- `console.log` (backend and frontend — use a logger)
- `debugger`
- `TODO` / `FIXME` introduced by the change (deferred work lives in the issue tracker or SDD artifacts, not in source comments)
- `any` in new files
