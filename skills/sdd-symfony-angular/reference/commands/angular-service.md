---
description: Scaffold an Angular service (HTTP API or state) from a SDD spec
---

# /angular-service

**Auxiliary scaffolding command**: create an Angular service (application singleton) for HTTP calls or state management.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentioning the creation of the service
- Available conventions: `.claude/rules/angular-conventions.md` and `.claude/rules/api-contracts.md`

## Steps

### 1. Identify the service to create

Ask for:
- Service name (PascalCase, `Service` suffix): `UserApiService`, `UserStateService`
- Feature (folder): `user`, `order`, etc.
- Type:
  - **API**: HTTP calls to the backend
  - **State**: state shared between components
  - **Logic**: business logic (validation, computation, transformation)

### 2. Load the SDD context

Read `spec.md`:
- Which endpoints the service calls (API side)
- Which public methods it exposes
- Which shared state it maintains (State side)

### 3. Load the conventions

Read `.claude/rules/angular-conventions.md` and `.claude/rules/api-contracts.md`:
- `@Injectable({ providedIn: 'root' })`
- `inject()` rather than constructor
- Explicit types on all requests/responses
- One responsibility per service

Then **discover the project's frontend state**: the frontend root (where `angular.json` lives — never assume `frontend/`), the existing service organization, the established HTTP conventions, the state-management strategy in place (NgRx, Signal Store, service-based signals, RxJS store…), any generated API contract types, and the configured test runner. The paths below are **greenfield defaults** — follow the discovered conventions; never impose one global state strategy.

### 4. Check for duplicates

```bash
# The check consumes the DISCOVERED frontend root (service organization: greenfield layout shown)
test -f <frontend-root>/src/app/features/<feature>/services/<name>.service.ts && echo "EXISTS" || echo "OK"
```

### 5. Generate an HTTP API service

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { UserResponse, CreateUserRequest, UpdateUserRequest } from '../models/user.model';

@Injectable({ providedIn: 'root' })
export class UserApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = '/api/users';

  list(): Observable<UserResponse[]> {
    return this.http.get<UserResponse[]>(this.baseUrl);
  }

  findById(id: number): Observable<UserResponse> {
    return this.http.get<UserResponse>(`${this.baseUrl}/${id}`);
  }

  create(payload: CreateUserRequest): Observable<UserResponse> {
    return this.http.post<UserResponse>(this.baseUrl, payload);
  }

  update(id: number, payload: UpdateUserRequest): Observable<UserResponse> {
    return this.http.put<UserResponse>(`${this.baseUrl}/${id}`, payload);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
```

### 6. Generate a State service (Signal-based)

```typescript
import { Injectable, computed, inject, signal } from '@angular/core';

import { UserApiService } from './user-api.service';
import { UserResponse } from '../models/user.model';

@Injectable({ providedIn: 'root' })
export class UserStateService {
  private readonly api = inject(UserApiService);

  // Internal state
  private readonly _users = signal<UserResponse[]>([]);
  private readonly _loading = signal(false);
  private readonly _error = signal<string | null>(null);
  private readonly _selectedId = signal<number | null>(null);

  // Public read-only state
  readonly users = this._users.asReadonly();
  readonly loading = this._loading.asReadonly();
  readonly error = this._error.asReadonly();

  // Derived computed values
  readonly selectedUser = computed(() => {
    const id = this._selectedId();
    return id ? this._users().find(u => u.id === id) ?? null : null;
  });

  // Actions
  loadAll(): void {
    this._loading.set(true);
    this._error.set(null);

    this.api.list().subscribe({
      next: users => {
        this._users.set(users);
        this._loading.set(false);
      },
      error: err => {
        this._error.set('Loading error');
        this._loading.set(false);
      },
    });
  }

  select(id: number): void {
    this._selectedId.set(id);
  }

  add(user: UserResponse): void {
    this._users.update(users => [...users, user]);
  }

  remove(id: number): void {
    this._users.update(users => users.filter(u => u.id !== id));
  }
}
```

### 7. Generate a pure Logic service

```typescript
import { Injectable } from '@angular/core';

import { UserResponse } from '../models/user.model';

@Injectable({ providedIn: 'root' })
export class UserPermissionService {
  isAdmin(user: UserResponse): boolean {
    return user.roles.includes('ROLE_ADMIN');
  }

  canEdit(currentUser: UserResponse, target: UserResponse): boolean {
    return this.isAdmin(currentUser) || currentUser.id === target.id;
  }

  canDelete(currentUser: UserResponse, target: UserResponse): boolean {
    return this.isAdmin(currentUser) && currentUser.id !== target.id;
  }
}
```

### 8. Generate/verify the associated models file

If the service uses TypeScript types that do not exist yet, propose creating them in `models/`:

```typescript
// <frontend-root>/src/app/features/user/models/user.model.ts (greenfield layout)

export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly createdAt: string;
  readonly roles: readonly string[];
}

export interface CreateUserRequest {
  readonly email: string;
  readonly password: string;
  readonly firstName?: string;
  readonly lastName?: string;
}

export interface UpdateUserRequest {
  readonly firstName?: string;
  readonly lastName?: string;
}
```

⚠️ Do not create the models manually if the project already provides its types: generated OpenAPI contract (the skill's contract command, e.g. `/api-contract`) or shared types from a monorepo (`packages/shared/types/`). See `.claude/rules/api-contracts.md`.

### 9. Generate the test skeleton

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

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  // Detailed tests to scaffold via /angular-test
});
```

### 10. Display and validate

Before writing:
- Service `.ts`
- Models (if created)
- Test skeleton
- Ask for confirmation

### 11. Write the files

Under the discovered frontend root and service organization (greenfield layout shown):

- `<frontend-root>/src/app/features/<feature>/services/<name>.service.ts`
- `<frontend-root>/src/app/features/<feature>/services/<name>.service.spec.ts`
- `<frontend-root>/src/app/features/<feature>/models/<name>.model.ts` (if created)

### 12. Announce

```
✅ Service created: <frontend-root>/src/app/features/user/services/user-api.service.ts

Type: HTTP API service
Exposed endpoints:
  - list()
  - findById(id)
  - create(payload)
  - update(id, payload)
  - delete(id)

Next steps:
- /angular-test to scaffold the detailed tests
- /sdd-implement for the next task
```

## Stop rules

- **Never overwrite an existing file**
- **Always `providedIn: 'root'`** (application singleton)
- **Always `inject()`** (no constructor injection)
- **Always type** HTTP return values
- **No `any`**
- **One responsibility per service**: API or State or Logic (never all mixed together)
- **For State services**: expose state as `readonly` via `.asReadonly()`
- **For API services**: return `Observable`s, do not systematically convert to Promise
- **No business logic in an API service**: just the HTTP calls and payload passing
- **Generated tests must run on the project's configured runner** — no runner-specific APIs in the skeleton
