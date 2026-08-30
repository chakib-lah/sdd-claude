# Test strategy — Symfony + Angular

> **Layer 2 — Specific to the full-stack Symfony + Angular stack.**

---

## Overview

| Layer | Required capability | Current parameters (discovered) |
|---|---|---|
| Backend unit / integration / functional | PHPUnit — **required** | suite names, directories, wrapper (PHPUnit config under the discovered backend root) |
| Frontend unit/component | Automated tests — **required**; **Vitest is the modern target runner** | actual runner (Vitest / Karma+Jasmine / Jest), `angular.json` test builder, project scripts |
| Frontend E2E | E2E coverage of critical full-stack workflows | configured tool (Playwright, Cypress, other) |

Both roots are discovered (never assumed to be `backend/`/`frontend/`); `<backend-root>`/`<frontend-root>` below stand for the discovered directories.

---

## Backend — PHPUnit

### Discovery first

**PHPUnit is required.** Suites, directories and execution wrappers are project facts: read the PHPUnit configuration under the discovered backend root — whichever variant the project uses (`phpunit.xml.dist`, `phpunit.xml` or `phpunit.dist.xml`) — list the declared `<testsuite>` entries, and use the project's established wrapper (Make/Docker/Composer). Never reorganize an existing test tree during an unrelated feature. Missing test infrastructure is a **PROJECT_TOOLING_GAP** (see `12-quality-gates.md`).

The three universal levels map onto the project's discovered suites (names vary — casing, abbreviations, merged levels):
- **unit**: mocks, no container (greenfield default directory `tests/Unit/`)
- **integration**: real database, `KernelTestCase` (greenfield default `tests/Integration/`)
- **functional**: HTTP end-to-end, `WebTestCase` (greenfield default `tests/Functional/`)

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
# Direct-host examples — use the project's own wrapper/targets when they exist
cd <backend-root>
vendor/bin/phpunit                              # all
vendor/bin/phpunit --testsuite=<suite-name>     # one discovered suite
make test                                       # if the project's Makefile defines it
```

---

## Frontend — Vitest is the modern target; the current runner is discovered

**Automated Angular tests are required.** The modern Layer-2 target runner is **Vitest** (the Angular CLI default for new projects since Angular 21). The runner actually in place is a **project fact**: read the `test` builder in `angular.json` and the test tooling in `package.json` before generating or running anything.

Runner states:

- **Vitest configured** — use the existing Vitest/Angular CLI configuration and project scripts as-is; do not add a custom Vitest config when the CLI builder already owns it.
- **Karma + Jasmine configured (brownfield)** — a supported **PROJECT_MIGRATION_GAP**, not the target: the current runner stays usable so feature work remains executable; generate Jasmine-compatible tests through the project's CLI wrapper; report the migration gap; never migrate the runner (or install Vitest) as a side effect of an unrelated feature. The Karma/Jasmine → Vitest migration is a dedicated task driven by the project's Angular version, build system and real configuration.
- **Jest configured (brownfield)** — a supported **discovered existing runner**: honor it, never mix runner APIs, and do not migrate to or away from it during a feature. Jest is not this skill's modern default target; if the project's Layer-3 policy targets Vitest, report the migration status.
- **No runner configured** — **PROJECT_TOOLING_GAP**: automated tests remain required; setting up the runner is a dedicated tooling change (greenfield default: Vitest via the Angular CLI).

The `TestBed` / `HttpTestingController` patterns below are runner-agnostic — they run under Vitest, Jasmine or Jest.

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
# Always via the project's configured scripts / CLI target — discover them first
cd <frontend-root>
npm test                              # runs whatever runner angular.json wires
npm test -- --coverage                # if the configured runner/builder supports it
```

---

## E2E — discover the configured tool

E2E coverage of the **critical full-stack workflows** is required at the appropriate level. The tool is a project fact: discover the existing Playwright/Cypress/other setup before writing E2E tests, and never force a project-wide E2E migration. Greenfield default: Playwright or Cypress. The Cypress material below is a **tool-specific example**, not a mandate.

### Cypress — Configuration (tool-specific example)

Greenfield installation:

```bash
cd <frontend-root>
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
cd <frontend-root>
npx cypress open                       # interactive mode
npx cypress run                        # CI mode (headless)
```

### Organization (greenfield example)

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

Review and greenfield targets — the enforced gate is the project's **configured** thresholds (discovered from its coverage/CI configuration), plus no coverage regression on changed code. Never present the table below as a project's current truth.

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
