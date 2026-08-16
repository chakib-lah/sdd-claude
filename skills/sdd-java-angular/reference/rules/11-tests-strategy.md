# Test strategy — Spring Boot + Angular

> **Layer 2 — Specific to the full-stack Spring Boot + Angular stack.**

---

## Overview

| Layer | Tools | Location |
|---|---|---|
| Backend Unit | JUnit 5 + Mockito + AssertJ | `backend/src/test/java/**/*Test.java` |
| Backend Integration | JUnit 5 + Spring Test (`*IT`) | `backend/src/test/java/**/*IT.java` |
| Frontend Unit | Karma+Jasmine (CLI default) or Jest | `frontend/src/**/*.spec.ts` |
| Frontend E2E (optional) | Cypress or Playwright | `frontend/e2e/` or `frontend/cypress/` |

---

## Backend — JUnit 5 / Mockito / AssertJ

> The backend testing rules below are self-contained. (The `sdd-java-backend` skill
> covers the same ground in more depth for backend-only projects, but nothing there
> is required to apply this file.)

### Organization

`src/test/java` mirrors `src/main/java` package for package. Split by class-name pattern:

- `*Test` → unit or slice test (no full context, no real DB unless a slice needs one)
- `*IT` or `*IntTest` → integration test (Spring context and/or real database)

Assertions with AssertJ (`assertThat(...)`) — not Hamcrest, not bare JUnit asserts.

### Unit example (service, mocks only)

```java
@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserServiceImpl sut;

    @Test
    void shouldReturnEmptyWhenUserNotFound() {
        // Covers AC-1
        when(userRepository.findById(42L)).thenReturn(Optional.empty());

        Optional<UserResponse> result = sut.findById(42L);

        assertThat(result).isEmpty();
    }
}
```

### Web slice example (controller contract)

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Test
    void shouldReturn404WhenUserNotFound() throws Exception {
        // Covers AC-2
        when(userService.findById(99L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/99"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.title").value("Resource not found"));
    }
}
```

Repository slices use `@DataJpaTest` against a real PostgreSQL (Testcontainers or
embedded); full flows use `@SpringBootTest(webEnvironment = RANDOM_PORT)` and are
named `*IT`. On Spring Boot 4 projects, prefer `RestTestClient` for web tests.

### Gradle task split

The `unitTest` / `integrationTest` tasks used below are **not built-in Gradle tasks** —
declare them in `backend/build.gradle`:

```groovy
tasks.register('unitTest', Test) {
    useJUnitPlatform()
    testClassesDirs = sourceSets.test.output.classesDirs
    classpath = sourceSets.test.runtimeClasspath
    include '**/*Test.class'
    exclude '**/*IT.class', '**/*IntTest.class'
}

tasks.register('integrationTest', Test) {
    useJUnitPlatform()
    testClassesDirs = sourceSets.test.output.classesDirs
    classpath = sourceSets.test.runtimeClasspath
    include '**/*IT.class', '**/*IntTest.class'
    shouldRunAfter tasks.named('unitTest')
}

tasks.named('check') {
    dependsOn 'unitTest', 'integrationTest'
}
```

Note: the default `test` task still runs everything. When the split tasks are wired
into `check`, exclude the default task from it (`check.dependsOn.remove(tasks.named('test'))`
— or, alternatively, `test.enabled = false`) to avoid running every test twice.

Maven equivalent: Surefire runs `*Test` during `test`, Failsafe runs `*IT` during
`verify` (declare the `maven-failsafe-plugin` with the `integration-test` and `verify`
goals). Only the `*IT` suffix is picked up by Failsafe defaults; `*IntTest` requires
explicit `<includes>` configuration — treat `*IntTest` as a Gradle-only convention.

### Commands

```bash
cd backend
./gradlew test                  # all tests
./gradlew unitTest              # unit only (*Test)
./gradlew integrationTest       # integration only (*IT)
./gradlew jacocoTestReport      # coverage report

# Maven equivalents
mvn test                        # unit tests (Surefire, *Test)
mvn verify                      # unit + integration (Failsafe, *IT)
```

Keep these commands exact — `/sdd-implement` and `/sdd-verify` read them.

---

## Frontend — Karma/Jasmine or Jest

The Angular CLI ships Karma+Jasmine by default on older versions; **since Angular 21,
Vitest is the default runner for new projects** (Karma is deprecated). Jest (via
`jest-preset-angular`) is a valid alternative on projects that already adopted it.
**Keep whichever runner the project uses** — do not migrate as a side effect of a
feature.

### Commands

```bash
cd frontend
ng test --watch=false --browsers=ChromeHeadless    # CI mode (Karma)
ng test                                            # watch mode (local dev)
ng test --watch=false --code-coverage              # with coverage

# Jest projects
npm test -- --coverage --watchAll=false
```

### Service unit tests (HTTP)

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

Use `provideHttpClientTesting()` (standalone providers). On older NgModule-based
projects, `HttpClientTestingModule` is the equivalent — same `HttpTestingController` API.

### Component tests with signals

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { UserCardComponent } from './user-card.component';

describe('UserCardComponent', () => {
  let fixture: ComponentFixture<UserCardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
  });

  it('should display user email', () => {
    fixture.componentRef.setInput('user', { id: 1, email: 'test@example.com' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('test@example.com');
  });

  it('should recompute filtered list when search term changes', () => {
    const component = fixture.componentInstance as any;
    component.users.set([{ id: 1, email: 'a@x.io' }, { id: 2, email: 'b@y.io' }]);
    component.searchTerm.set('a@');

    expect(component.filteredUsers()).toHaveSize(1); // Jasmine (Jest: toHaveLength)
  });
});
```

- Signal inputs are set via `fixture.componentRef.setInput(...)`
- `computed()` values are asserted by calling them after setting their source signals
- On zoneless projects, use `await fixture.whenStable()` instead of relying on
  Zone.js-triggered change detection

---

## E2E — optional smoke on the main flows

E2E is **optional** on this stack: add Cypress or Playwright smoke tests only for
the main user flows (login, primary CRUD journey), not for UI details.

```typescript
// cypress/e2e/user-listing.cy.ts
describe('User listing', () => {
  beforeEach(() => {
    cy.intercept('GET', '/api/users', { fixture: 'users.json' }).as('getUsers');
    cy.visit('/users');
  });

  it('displays a list of users', () => {
    cy.wait('@getUsers');
    cy.get('[data-test="user-row"]').should('have.length', 3);
  });
});
```

```bash
cd frontend
npx cypress run          # CI mode (headless)
npx playwright test      # Playwright equivalent
```

Use `data-test` attributes as selectors, never CSS classes or IDs:

```html
<!-- ✅ Good -->
<button data-test="submit-button">Submit</button>

<!-- ❌ Bad: coupled to styling -->
<button class="btn-primary">Submit</button>
```

---

## Cross-cutting conventions

### AC-driven tests

Each acceptance criteria (AC) in the spec must have at minimum:
- A unit or integration test on the backend side if the logic lives in the backend
- A unit test on the frontend side if the logic lives in the frontend
- An E2E smoke test only if the AC is a complete user workflow

Tag the covering test with a `// Covers AC-n` comment on both sides.

### Shared fixtures backend ↔ frontend

For tests that depend on API payloads, keep one canonical JSON example per DTO
(from the OpenAPI contract, see `api-contracts.md`) and reuse it:
- Backend: as the expected body in `@WebMvcTest` assertions
- Frontend: as the `req.flush(...)` payload and Cypress fixture

This catches contract drift in unit tests before it reaches E2E.

### Time-dependent code

Backend: inject a `java.time.Clock` bean, use `Clock.fixed(...)` in tests.
Frontend: use `jasmine.clock()` / `jest.useFakeTimers()` — never real `setTimeout` waits.

---

## Coverage targets

| Layer | Target |
|---|---|
| Backend business services | ≥ 90% |
| Backend mappers / validators | 100% (mostly generated + trivial) |
| Backend repositories (custom queries) | ≥ 80% (via `@DataJpaTest`) |
| Backend controllers | ≥ 70% (via `@WebMvcTest` / integration) |
| Frontend services | ≥ 85% |
| Frontend components | ≥ 70% |
| E2E | critical workflows only, no coverage target |

### What /sdd-verify runs on each side

| Side | Commands |
|---|---|
| Backend | `./gradlew unitTest integrationTest` (or `mvn verify`) + `./gradlew jacocoTestCoverageVerification` |
| Frontend | `ng test --watch=false --browsers=ChromeHeadless` (or `npm test -- --watchAll=false`) |
| E2E (if present) | `npx cypress run` or `npx playwright test` — only when the task touched a covered flow |

---

## CI/CD

### Typical pipeline

```yaml
stages:
  - test-backend
  - test-frontend
  - e2e

backend-tests:
  stage: test-backend
  image: gradle:9-jdk21
  services:
    - postgres:16
  variables:
    SPRING_PROFILES_ACTIVE: ci
    POSTGRES_DB: app_test
    POSTGRES_USER: app
    POSTGRES_PASSWORD: app
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/app_test
    SPRING_DATASOURCE_USERNAME: app
    SPRING_DATASOURCE_PASSWORD: app
  script:
    - cd backend
    - ./gradlew unitTest integrationTest jacocoTestReport --no-daemon
  artifacts:
    reports:
      junit: backend/build/test-results/**/*.xml

frontend-tests:
  stage: test-frontend
  image: node:22
  script:
    - cd frontend && npm ci
    - npx ng test --watch=false --browsers=ChromeHeadless --code-coverage

e2e-tests:
  stage: e2e
  image: cypress/included:14.5.0   # pin the version in real projects
  script:
    - cd frontend && npm ci
    - npm run start:e2e &
    - npx wait-on http://localhost:4200
    - npx cypress run
```

Karma in CI needs a Chromium-capable image (`node:22` + installed Chromium, or a
browsers image) — set `CHROME_BIN` accordingly.

---

## Anti-patterns

- ❌ Mocking repositories in backend integration tests (use the real DB — that is the point)
- ❌ `@SpringBootTest` for logic testable with plain Mockito (context startup cost)
- ❌ Frontend unit tests that make real HTTP calls (always `HttpTestingController`)
- ❌ E2E tests to verify a UI detail (use a component unit test instead)
- ❌ Tests that depend on timing (`cy.wait(2000)`, `Thread.sleep(...)`) — use aliases/Awaitility
- ❌ Assertion-free tests or `expect(true).toBeTrue()`
- ❌ Order-dependent tests sharing mutable state
- ❌ Testing an AC on only one side when the logic spans both (backend validation + frontend display)
