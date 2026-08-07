---
description: Scaffold Angular tests (component, service, pipe) from a SDD spec
---

# /angular-test

**Auxiliary scaffolding command**: create the tests for an existing Angular component, service, or pipe.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- The class to test must already exist
- Available conventions: `.claude/rules/11-tests-strategy.md`

## Steps

### 1. Identify the target

Ask for:
- Path to the file to test (e.g. `frontend/src/app/features/user/services/user-api.service.ts`)
- Test type: `Component`, `Service`, or `Pipe`

Automatic detection:
- `.component.ts` suffix → Component
- `.service.ts` suffix → Service
- `.pipe.ts` suffix → Pipe

### 2. Load the conventions

Read `.claude/rules/11-tests-strategy.md`:
- Jest (recommended) or Karma+Jasmine
- TestBed for components
- HttpTestingController for HTTP services
- `data-test` attributes for selectors

### 3. Load the SDD context

Read `spec.md` for the acceptance criteria. Every AC relevant to the frontend becomes a test.

### 4. Read the target

Identify:
- Required imports
- Inputs/Outputs (components)
- Public methods (services)
- Injected dependencies

### 5. Generate according to type

#### Component

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';

import { UserCardComponent } from './user-card.component';
import { UserResponse } from '../../models/user.model';

describe('UserCardComponent', () => {
  let component: UserCardComponent;
  let fixture: ComponentFixture<UserCardComponent>;

  const mockUser: UserResponse = {
    id: 1,
    email: 'test@example.com',
    firstName: 'John',
    lastName: 'Doe',
    createdAt: '2026-01-01T00:00:00Z',
    roles: ['ROLE_USER'],
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.componentRef.setInput('user', mockUser);
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  /**
   * Covers AC-X: <statement>
   */
  it('should display user email', () => {
    fixture.componentRef.setInput('user', mockUser);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('test@example.com');
  });

  /**
   * Covers AC-X: <statement>
   */
  it('should emit edit event with user id when edit button clicked', () => {
    fixture.componentRef.setInput('user', mockUser);
    fixture.detectChanges();

    let emittedId: number | undefined;
    component.edit.subscribe((id: number) => emittedId = id);

    const editButton = fixture.debugElement.query(By.css('[data-test="edit-button"]'));
    editButton.nativeElement.click();

    expect(emittedId).toBe(1);
  });

  /**
   * Covers AC-X: <statement>
   */
  it('should apply highlighted class when highlighted input is true', () => {
    fixture.componentRef.setInput('user', mockUser);
    fixture.componentRef.setInput('highlighted', true);
    fixture.detectChanges();

    const card = fixture.debugElement.query(By.css('.user-card'));
    expect(card.nativeElement.classList).toContain('user-card--highlighted');
  });
});
```

#### HTTP API service

```typescript
import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

import { UserApiService } from './user-api.service';
import { UserResponse, CreateUserRequest } from '../models/user.model';

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

  /**
   * Covers AC-X: <statement>
   */
  it('should GET user list', () => {
    const mockUsers: UserResponse[] = [
      { id: 1, email: 'a@b.c', firstName: null, lastName: null, createdAt: '2026-01-01', roles: [] },
    ];

    service.list().subscribe(users => {
      expect(users).toEqual(mockUsers);
    });

    const req = httpMock.expectOne('/api/users');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers);
  });

  /**
   * Covers AC-X: <statement>
   */
  it('should POST to create a user', () => {
    const payload: CreateUserRequest = { email: 'new@example.com', password: 'secret123' };
    const mockResponse: UserResponse = {
      id: 42,
      email: 'new@example.com',
      firstName: null,
      lastName: null,
      createdAt: '2026-01-01',
      roles: ['ROLE_USER'],
    };

    service.create(payload).subscribe(user => {
      expect(user).toEqual(mockResponse);
    });

    const req = httpMock.expectOne('/api/users');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(payload);
    req.flush(mockResponse, { status: 201, statusText: 'Created' });
  });

  it('should handle 404 on findById', () => {
    let errorStatus: number | undefined;

    service.findById(999).subscribe({
      next: () => fail('expected error'),
      error: err => errorStatus = err.status,
    });

    const req = httpMock.expectOne('/api/users/999');
    req.flush({ message: 'Not found' }, { status: 404, statusText: 'Not Found' });

    expect(errorStatus).toBe(404);
  });
});
```

#### State service (Signal-based)

```typescript
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';

import { UserStateService } from './user-state.service';
import { UserApiService } from './user-api.service';

describe('UserStateService', () => {
  let service: UserStateService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        UserStateService,
        UserApiService,
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });

    service = TestBed.inject(UserStateService);
  });

  it('should start with empty users list', () => {
    expect(service.users()).toEqual([]);
  });

  /**
   * Covers AC-X: <statement>
   */
  it('should add a user', () => {
    const user = { id: 1, email: 'a@b.c', firstName: null, lastName: null, createdAt: '2026-01-01', roles: [] };
    service.add(user);

    expect(service.users()).toEqual([user]);
  });
});
```

#### Pipe

```typescript
import { TruncatePipe } from './truncate.pipe';

describe('TruncatePipe', () => {
  let pipe: TruncatePipe;

  beforeEach(() => {
    pipe = new TruncatePipe();
  });

  it('should return the original string if shorter than limit', () => {
    expect(pipe.transform('Hello', 10)).toBe('Hello');
  });

  it('should truncate strings longer than limit', () => {
    expect(pipe.transform('Hello world long text', 10)).toBe('Hello worl…');
  });

  it('should use default limit of 50', () => {
    const long = 'a'.repeat(60);
    expect(pipe.transform(long).length).toBe(51);
  });
});
```

### 6. Generate one test per relevant acceptance criterion

For ACs concerning the frontend (display, interaction, navigation):

```typescript
/**
 * Covers AC-X: <exact statement>
 */
it('should <description>', () => {
  // TODO: implement via /sdd-implement
  pending('To implement');
});
```

(`pending()` in Jasmine, or `xit()`/`.todo` in Jest)

### 7. Display and validate

Before writing:
- List of generated tests
- AC ↔ test mapping
- Ask for confirmation

### 8. Write the file

Next to the source file, with the `.spec.ts` suffix:
- `user-card.component.spec.ts`
- `user-api.service.spec.ts`
- `truncate.pipe.spec.ts`

### 9. Verify that the tests are detected

```bash
cd frontend
npm test -- --listTests | grep <name>
```

### 10. Announce

```
✅ Tests scaffolded: frontend/src/app/features/user/components/user-card/user-card.component.spec.ts

Tests generated: N
  - N ACs covered
  - X complete tests
  - Y `pending` tests to finalize via /sdd-implement

Next step:
- npm test to verify that the tests pass
- /sdd-implement for the next task
```

## Stop rules

- **At least one test per acceptance criterion** (frontend side)
- **No `expect(true).toBe(true)`**: use `pending()` or `it.todo`
- **`data-test` attributes** for selectors (no CSS classes)
- **`httpMock.verify()`** in `afterEach` for HTTP services (detects outstanding requests)
- **No unfinished subscribe** in a test (use `done`, `fakeAsync`, or wait for completion)
- **No Angular mocks** (`MockNgZone`, etc.): use `TestBed`
- **No tests that depend on real timing**: use `fakeAsync` + `tick()` for debounces
- **Document each test with the AC** it covers
