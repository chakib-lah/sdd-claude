# Test strategy — Symfony + Angular

> **Layer 2 — Specific to the full-stack Symfony + Angular stack.**

---

## Overview

| Layer | Tools | Location |
|---|---|---|
| Backend Unit | PHPUnit | `backend/tests/Unit/` |
| Backend Integration | PHPUnit + KernelTestCase | `backend/tests/Integration/` |
| Backend Functional | PHPUnit + WebTestCase | `backend/tests/Functional/` |
| Frontend Unit | Jest (recommended) or Karma+Jasmine | `frontend/src/**/*.spec.ts` |
| Frontend E2E | Cypress or Playwright | `frontend/e2e/` |

---

## Backend — PHPUnit

### Configuration

See also the backend conventions in `sdd-php-symfony`:
- `tests/Unit/`: unit tests with mocks
- `tests/Integration/`: tests against a real database (KernelTestCase)
- `tests/Functional/`: end-to-end HTTP tests (WebTestCase)

### Unit example

```php
final class UserServiceTest extends TestCase
{
    private UserRepository|MockObject $repository;
    private UserService $sut;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(UserRepository::class);
        $this->sut = new UserService($this->repository);
    }

    public function testReturnsNullWhenUserNotFound(): void
    {
        $this->repository->method('find')->willReturn(null);
        self::assertNull($this->sut->find(42));
    }
}
```

### Functional example (controller endpoint)

```php
final class GetUserControllerTest extends WebTestCase
{
    public function testReturns200AndJsonWhenUserExists(): void
    {
        $client = static::createClient();
        $client->request('GET', '/api/users/1');

        self::assertResponseIsSuccessful();
        self::assertJson($client->getResponse()->getContent());
    }
}
```

### Commands

```bash
cd backend
vendor/bin/phpunit                        # all
vendor/bin/phpunit --testsuite=Unit       # unit
vendor/bin/phpunit --testsuite=Functional # functional
make test                                  # via Makefile
```

---

## Frontend — Jest (recommended) or Karma+Jasmine

### Why Jest

- Faster than Karma
- No browser required for unit tests
- Built-in snapshots
- Simplified configuration with `jest-preset-angular`

Installation:

```bash
npm install --save-dev jest @types/jest jest-preset-angular @angular-builders/jest
```

`jest.config.js` configuration:

```js
module.exports = {
  preset: 'jest-preset-angular',
  setupFilesAfterEach: ['<rootDir>/src/setup-jest.ts'],
  testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/dist/'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.spec.ts',
    '!src/main.ts',
    '!src/environments/**',
  ],
};
```

### Service unit tests

```typescript
import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { UserApiService } from './user-api.service';

describe('UserApiService', () => {
  let service: UserApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        UserApiService,
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });

    service = TestBed.inject(UserApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('should GET user by id', () => {
    const mockUser = { id: 1, email: 'test@example.com', createdAt: '2026-01-01T00:00:00Z' };

    service.findById(1).subscribe(user => {
      expect(user).toEqual(mockUser);
    });

    const req = httpMock.expectOne('/api/users/1');
    expect(req.request.method).toBe('GET');
    req.flush(mockUser);
  });
});
```

### Component unit tests

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { UserCardComponent } from './user-card.component';

describe('UserCardComponent', () => {
  let component: UserCardComponent;
  let fixture: ComponentFixture<UserCardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
  });

  it('should display user email', () => {
    fixture.componentRef.setInput('user', { id: 1, email: 'test@example.com' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('test@example.com');
  });

  it('should emit edit event when edit button clicked', () => {
    let emitted: number | undefined;
    component.edit.subscribe((id: number) => emitted = id);

    fixture.componentRef.setInput('user', { id: 42, email: 'a@b.c' });
    fixture.detectChanges();

    fixture.nativeElement.querySelector('button.edit').click();
    expect(emitted).toBe(42);
  });
});
```

### Commands

```bash
cd frontend
npm test                              # all (Jest)
npm test -- --watch                   # watch mode
npm test -- --coverage                # with coverage
npm test -- user-card.component       # a single file
```

---

## E2E — Cypress (recommended) or Playwright

### Cypress — Configuration

Installation:

```bash
cd frontend
npm install --save-dev cypress
```

`cypress.config.ts` configuration:

```typescript
import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4200',
    supportFile: 'cypress/support/e2e.ts',
    specPattern: 'cypress/e2e/**/*.cy.ts',
  },
});
```

### Cypress example

```typescript
describe('User listing', () => {
  beforeEach(() => {
    cy.intercept('GET', '/api/users', { fixture: 'users.json' }).as('getUsers');
    cy.visit('/users');
  });

  it('displays a list of users', () => {
    cy.wait('@getUsers');
    cy.get('[data-test="user-row"]').should('have.length', 3);
  });

  it('navigates to user detail on click', () => {
    cy.get('[data-test="user-row"]').first().click();
    cy.url().should('include', '/users/1');
  });
});
```

### Commands

```bash
cd frontend
npx cypress open                       # interactive mode
npx cypress run                        # CI mode (headless)
```

### Organization

```
frontend/
└── cypress/
    ├── e2e/
    │   ├── user-listing.cy.ts
    │   └── order-flow.cy.ts
    ├── fixtures/
    │   ├── users.json
    │   └── orders.json
    └── support/
        ├── commands.ts
        └── e2e.ts
```

---

## Cross-cutting conventions

### Test selectors on the Angular side

Use `data-test` attributes rather than CSS classes or IDs:

```html
<!-- ✅ Good -->
<button data-test="submit-button">Submit</button>

<!-- ❌ Bad: coupled to styling or accessibility -->
<button class="btn-primary">Submit</button>
```

In tests:

```typescript
cy.get('[data-test="submit-button"]').click();
```

### Shared fixtures backend ↔ frontend

For E2E tests that depend on a particular database state, either:
- Fully reset the database before each suite + load Doctrine fixtures via a command
- Intercept on the Cypress side (HTTP mock) for fast tests

### AC-driven tests

Each acceptance criteria (AC) in the spec must have at minimum:
- A unit or integration test on the backend side if the logic lives in the backend
- A unit test on the frontend side if the logic lives in the frontend
- An E2E test if the AC is a complete user workflow

---

## Coverage targets

| Layer | Target |
|---|---|
| Backend business services | ≥ 90% |
| Backend repositories | ≥ 80% (integration) |
| Backend controllers | ≥ 70% (functional) |
| Frontend services | ≥ 85% |
| Frontend components | ≥ 70% |
| E2E | critical workflows only |

---

## In the project's CI

The suites above run in the project's **existing** pipeline — the toolkit prescribes what must be green (backend unit + integration with their database, frontend unit, E2E on the assembled stack), never how the pipeline is wired.

## Anti-patterns

- ❌ E2E tests to verify a UI detail (use a Component unit test instead)
- ❌ Unit tests that make real HTTP calls
- ❌ Tests that depend on timing (use `cy.wait('@alias')`, not `cy.wait(2000)`)
- ❌ Snapshots of large DOM trees (fragile, unreadable in review)
- ❌ Tests that share state with each other
- ❌ Mocks so complex they duplicate the implementation under test
