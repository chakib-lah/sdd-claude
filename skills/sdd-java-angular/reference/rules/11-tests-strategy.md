# Test strategy — Spring Boot + Angular

> **Layer 2 — Specific to the full-stack Spring Boot + Angular stack.**

---

## Overview

| Layer | Required capability | Current parameters (discovered) |
|---|---|---|
| Backend unit / slice / integration | JUnit 5 — **required** | build tool, wrapper location, actual test tasks/goals, suite/naming convention, DB strategy |
| Frontend unit/component | Automated tests — **required**; **Vitest is the modern target runner** | actual runner (Vitest / Karma+Jasmine / Jest), `angular.json` test builder, project scripts |
| Frontend E2E | E2E coverage of critical full-stack workflows | configured tool (Cypress, Playwright, other) |

Both roots are discovered (never assumed to be `backend/`/`frontend/`; the backend root — and the Gradle/Maven wrapper — may live at the repository root); `<backend-root>`/`<frontend-root>` below stand for the discovered directories.

---

## Backend — JUnit 5 / Mockito / AssertJ

### Discovery first

**JUnit 5 automated tests are required.** How the project splits and runs them is a set of **project facts** — read the build configuration under the discovered backend root before generating or running anything:

- **Build tool and wrapper**: Gradle (`./gradlew` at its actual location) or Maven — never assume the wrapper sits in a `backend/` subdirectory.
- **Test tasks/goals**: list what the build defines (`./gradlew tasks`, or the POM's surefire/failsafe configuration). Custom `unitTest`/`integrationTest` tasks are a common convention — often declared in an included build script — but they are **not built-in Gradle facts**; a project may only have the default `test` task.
- **Suite/naming convention**: name-pattern splits (`*Test` vs `*IT` / `*IntTest` / `*IntegrationTest`), dedicated source sets (`src/integrationTest/java`), or tag-based splits are all valid established conventions — discover the one in place and follow it; never introduce a second incompatible convention.
- **Database strategy**: Testcontainers, an existing embedded PostgreSQL setup, or a CI database service — follow the existing setup.

Missing test infrastructure is a **PROJECT_TOOLING_GAP** (see `12-quality-gates.md`).

The universal levels map onto the project's discovered suites (greenfield defaults shown):

- `*Test` → unit or slice test (no full context, no real DB unless a slice needs one)
- `*IT` → integration test (Spring context and/or real database)

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
        when(userService.findById(99L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/99"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.title").value("Resource not found"));
    }
}
```

Repository slices use `@DataJpaTest` against a real PostgreSQL (Testcontainers or
embedded — follow the existing setup); full flows use
`@SpringBootTest(webEnvironment = RANDOM_PORT)` and belong to the integration suite.
On Spring Boot 4 projects, prefer `RestTestClient` for web tests.

### Gradle task split (greenfield example)

`unitTest` / `integrationTest` are **not built-in Gradle tasks** — a greenfield project declares them (existing projects often declare the same split in a dedicated build script; discover theirs instead of re-declaring):

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
goals). Only the `*IT` suffix is picked up by Failsafe defaults; other suffixes require
explicit `<includes>` configuration.

### Commands

```bash
# Via the project wrapper at its discovered location — invoke the DISCOVERED tasks
cd <repo-root>/<backend-root>
./gradlew test                        # always valid: the default task runs everything
./gradlew <unit-test-task>            # the discovered fast suite (greenfield default: unitTest)
./gradlew <integration-test-task>     # the discovered integration suite (greenfield default: integrationTest)

# Maven equivalents
mvn test                              # unit tests (Surefire)
mvn verify                            # unit + integration (Failsafe)
```

`/sdd-implement` and `/sdd-verify` run the **discovered** commands — resolve them once from the build configuration and reuse them consistently.

---

## Frontend — Vitest is the modern target; the current runner is discovered

**Automated Angular tests are required.** The modern Layer-2 target runner is **Vitest** (the Angular CLI default for new projects since Angular 21; Karma is deprecated). The runner actually in place is a **project fact**: read the `test` builder in `angular.json` and the test tooling in `package.json` before generating or running anything.

Runner states:

- **Vitest configured** — use the existing Vitest/Angular CLI configuration and project scripts as-is; do not add a custom Vitest config when the CLI builder already owns it.
- **Karma + Jasmine configured (brownfield)** — a supported **PROJECT_MIGRATION_GAP**, not the target: the current runner stays usable so feature work remains executable; generate Jasmine-compatible tests through the project's CLI wrapper; report the migration gap; never migrate the runner (or install Vitest) as a side effect of an unrelated feature.
- **Jest configured (brownfield)** — a supported **discovered existing runner**: honor it, never mix runner APIs, and do not migrate to or away from it during a feature.
- **No runner configured** — **PROJECT_TOOLING_GAP**: automated tests remain required; setting up the runner is a dedicated tooling change (greenfield default: Vitest via the Angular CLI).

The `TestBed` / `HttpTestingController` patterns below are runner-agnostic — they run under Vitest, Jasmine or Jest.

### Commands

```bash
# Always via the project's configured scripts / CLI target — discover them first
cd <repo-root>/<frontend-root>
npm test                              # runs whatever runner angular.json wires
npm test -- --coverage                # if the configured runner/builder supports it
```

Runner-specific flags (Karma's `--browsers=ChromeHeadless --watch=false`, Jest's `--watchAll=false`) belong to the **discovered** runner — never emit them universally.

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

    expect(component.filteredUsers().length).toBe(1); // assertion style per the discovered runner
  });
});
```

- Signal inputs are set via `fixture.componentRef.setInput(...)`
- `computed()` values are asserted by calling them after setting their source signals
- On zoneless projects, use `await fixture.whenStable()` instead of relying on
  Zone.js-triggered change detection

---

## E2E — optional smoke on the main flows

E2E is **optional** on this stack: smoke tests only for the main user flows (login, primary CRUD journey), not for UI details. The tool is a project fact — discover the existing Cypress/Playwright/other setup before writing E2E tests, and never force a project-wide E2E migration.

```typescript
// cypress/e2e/user-listing.cy.ts — tool-specific example
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
cd <repo-root>/<frontend-root>
npx cypress run          # CI mode (headless) — Cypress example
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

The AC ↔ test mapping lives in the SDD artifacts (`plan.md` test strategy, `tasks.md`) and the verification gates — never as a comment or SDD reference in test source on either side; tests are named for the behavior they attest.

### Shared fixtures backend ↔ frontend

For tests that depend on API payloads, keep one canonical JSON example per DTO
(from the OpenAPI contract, see `50-api-contracts.md`) and reuse it:
- Backend: as the expected body in `@WebMvcTest` assertions
- Frontend: as the `req.flush(...)` payload and E2E fixture

This catches contract drift in unit tests before it reaches E2E.

### Time-dependent code

Backend: inject a `java.time.Clock` bean, use `Clock.fixed(...)` in tests.
Frontend: use the discovered runner's fake-timer facilities — never real `setTimeout` waits.

---

## Coverage targets

Review and greenfield targets — the enforced gate is the project's **configured** thresholds (discovered from its coverage/CI configuration), plus no coverage regression on changed code. Never present the table below as a project's current truth.

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
| Backend | the discovered test tasks/goals via the project wrapper (greenfield defaults: `./gradlew unitTest integrationTest`, or `mvn verify`) + the configured coverage verification where one exists |
| Frontend | the project's configured test script (`npm test` through the discovered runner) |
| E2E (if present) | the configured E2E tool — only when the task touched a covered flow |

---

## In the project's CI

The suites above run in the project's **existing** pipeline — the toolkit prescribes what must be green (backend unit then integration suites with their database, frontend unit through the discovered runner, E2E on the assembled stack), never how the pipeline is wired.

## Anti-patterns

- ❌ Mocking repositories in backend integration tests (use the real DB — that is the point)
- ❌ `@SpringBootTest` for logic testable with plain Mockito (context startup cost)
- ❌ Frontend unit tests that make real HTTP calls (always `HttpTestingController`)
- ❌ E2E tests to verify a UI detail (use a component unit test instead)
- ❌ Tests that depend on timing (`cy.wait(2000)`, `Thread.sleep(...)`) — use aliases/Awaitility
- ❌ Assertion-free tests or `expect(true).toBeTrue()`
- ❌ Order-dependent tests sharing mutable state
- ❌ Testing an AC on only one side when the logic spans both (backend validation + frontend display)
- ❌ Running or generating against assumed test tasks or runner flags instead of the discovered ones
