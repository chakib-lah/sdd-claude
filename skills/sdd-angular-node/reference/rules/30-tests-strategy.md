---
description: Layer 2 — Angular + Node.js test strategy
---

# Test strategy — Angular + Node.js

> **Layer 2 — Specific to the Angular + Node.js stack.**

---

## Node.js backend

### Unit tests (Jest)

```bash
npm test                           # All tests
npm test -- --testPathPattern=user # Tests for a specific file
npm test -- --coverage             # With coverage
```

Conventions:
- `*.test.ts` co-located with the source file
- `describe` + `it` readable as sentences
- Mocks via `jest.mock()` or manual injection

### Integration tests (Supertest)

```typescript
import request from 'supertest';
import { app } from '../app';

describe('POST /api/users', () => {
  it('returns 201 with created user', async () => {
    const res = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com', password: 'password123' });
    
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
  });
});
```

---

## Angular frontend

### Component tests (Jest + Testing Library or Karma)

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { UserListComponent } from './user-list.component';

describe('UserListComponent', () => {
  let component: UserListComponent;
  let fixture: ComponentFixture<UserListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserListComponent],
    }).compileComponents();
    fixture = TestBed.createComponent(UserListComponent);
    component = fixture.componentInstance;
  });

  it('should display users', () => {
    // arrange + act + assert
  });
});
```

### `data-test` attributes for selectors

```html
<button data-test="submit-btn">Submit</button>
```

```typescript
const btn = fixture.nativeElement.querySelector('[data-test="submit-btn"]');
```

---

## E2E tests (Playwright)

```typescript
test('user can log in', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-test="email"]', 'user@example.com');
  await page.fill('[data-test="password"]', 'password');
  await page.click('[data-test="login-btn"]');
  await expect(page).toHaveURL('/dashboard');
});
```

---

## Commands

```bash
# Backend
npm test                   # Unit + integration tests
npm run test:coverage      # With coverage

# Frontend
npm test                   # Component tests
npm run test:e2e           # Playwright E2E tests

# Global (monorepo)
npm run test:all           # Backend + frontend
```
