# Angular Conventions

> **Layer 2 — Specific to the Angular frontend.**

---

## Target version

- **Angular**: 17+ minimum (20+ recommended — zoneless change detection is stable since 20.2 and the default for new projects since 21)
- **TypeScript**: 5.x+
- **Node**: 20.x / 22.x / 24.x LTS (20.x EOL April 2026)
- **RxJS**: 7.x — signals-first: RxJS to fetch and transform, signals to store and display

Adapt per project. Legacy projects on NgModules/zone.js are recorded as-is: migrate incrementally (OnPush everywhere → UI state to signals → zoneless), never in one pass.

---

## Components

### Standalone by default (Angular 17+)

```typescript
import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-card.component.html',
  styleUrl: './user-card.component.scss',
})
export class UserCardComponent {
  // ...
}
```

- ✅ `standalone: true` everywhere
- ✅ `ChangeDetectionStrategy.OnPush` by default
- ❌ No more NgModules for new components

### Inputs and Outputs (signal-based)

Angular provides signal-based inputs and outputs (`input()` since 17.1, `output()` since 17.3 — both long stable):

```typescript
import { Component, input, output } from '@angular/core';

@Component({ /* ... */ })
export class UserCardComponent {
  // Signal-based inputs
  readonly user = input.required<UserResponse>();
  readonly highlighted = input(false);  // optional with default value

  // Signal-based outputs
  readonly edit = output<number>();
  readonly delete = output<number>();

  protected onEditClick(): void {
    this.edit.emit(this.user().id);
  }
}
```

The old `@Input()` / `@Output()` syntax is acceptable but should be avoided for new code.

### Selectors

- ✅ `app-` prefix for application components
- ✅ `kebab-case` for elements: `<app-user-card>`
- ✅ `camelCase` for attribute directives: `appHighlight`

### Component structure

```
user-card/
├── user-card.component.ts         ← Logic
├── user-card.component.html       ← Template
├── user-card.component.scss       ← Scoped styles
└── user-card.component.spec.ts    ← Tests
```

### Business logic out of the template

```html
<!-- ❌ Bad: logic in the template -->
@if (user().status === 'active' && user().roles.includes('admin')) {
  <div>Admin</div>
}

<!-- ✅ Good: computed signal -->
@if (isActiveAdmin()) {
  <div>Admin</div>
}
```

```typescript
protected readonly isActiveAdmin = computed(() => 
  this.user().status === 'active' && this.user().roles.includes('admin')
);
```

---

## Signals (Angular 17+)

### Local component state

```typescript
import { Component, signal, computed } from '@angular/core';

@Component({ /* ... */ })
export class UserListComponent {
  protected readonly users = signal<User[]>([]);
  protected readonly searchTerm = signal('');
  protected readonly loading = signal(false);

  // Derived computed
  protected readonly filteredUsers = computed(() => {
    const term = this.searchTerm().toLowerCase();
    return this.users().filter(u => u.email.toLowerCase().includes(term));
  });

  // Immutable mutation
  protected addUser(user: User): void {
    this.users.update(users => [...users, user]);
  }
}
```

### Effects (reacting to changes)

```typescript
import { effect } from '@angular/core';

constructor() {
  effect(() => {
    console.log('User changed:', this.user());
    // Good for side effects (logs, localStorage, etc.)
    // Bad for state mutations (use computed instead)
  });
}
```

### RxJS ↔ Signal conversion

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

// Observable → Signal
private readonly userApi = inject(UserApiService);
protected readonly user = toSignal(this.userApi.findById(42), { initialValue: null });

// Signal → Observable
const searchTerm$ = toObservable(this.searchTerm);
```

### When to use what

| Need | Tool |
|---|---|
| Synchronous local component state | `signal()` |
| Derivation from other signals | `computed()` |
| Reacting to a change | `effect()` |
| HTTP streams, asynchronous events | RxJS `Observable` |
| Stream → signal conversion | `toSignal()` |
| Signal → stream conversion | `toObservable()` |

---

## Services

### Application-wide singleton

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class UserApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = '/api/users';

  findById(id: number): Observable<UserResponse> {
    return this.http.get<UserResponse>(`${this.baseUrl}/${id}`);
  }

  list(): Observable<UserResponse[]> {
    return this.http.get<UserResponse[]>(this.baseUrl);
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

### One responsibility per service

- `UserApiService`: HTTP calls only
- `UserStateService`: shared state (if needed)
- `UserCacheService`: caching (if needed)
- `UserPermissionService`: permission checks

No "God" service that mixes HTTP + state + transformation.

### `inject()` vs constructor

```typescript
// ✅ Recommended (Angular 14+)
export class UserListComponent {
  private readonly userApi = inject(UserApiService);
  private readonly router = inject(Router);
}

// Acceptable but more verbose
export class UserListComponent {
  constructor(
    private readonly userApi: UserApiService,
    private readonly router: Router,
  ) {}
}
```

---

## Types and interfaces

### API models

```typescript
// frontend/src/app/features/user/models/user.model.ts

export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly createdAt: string;  // ISO 8601
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

### Union types for enumerations

```typescript
export type UserStatus = 'active' | 'pending' | 'suspended' | 'deleted';
export type OrderStatus = 'draft' | 'submitted' | 'approved' | 'rejected';
```

### Generation from OpenAPI (recommended)

If the backend exposes an OpenAPI contract via `nelmio/api-doc-bundle`:

```bash
npm install --save-dev @openapitools/openapi-generator-cli

npx openapi-generator-cli generate \
  -i http://localhost:8000/api/docs.json \
  -g typescript-angular \
  -o src/app/generated
```

See `api-contracts.md` for details.

### No `any`

- ❌ `function process(data: any): any`
- ✅ `function process<T>(data: T): T`
- ✅ If truly unknown: `unknown` then narrowing with type guards

---

## RxJS — Best practices

### No subscribe without unsubscribe

```typescript
// ❌ Guaranteed memory leak
ngOnInit(): void {
  this.userApi.list().subscribe(users => this.users.set(users));
}

// ✅ Option 1: takeUntilDestroyed (Angular 16+)
private readonly destroyRef = inject(DestroyRef);

ngOnInit(): void {
  this.userApi.list()
    .pipe(takeUntilDestroyed(this.destroyRef))
    .subscribe(users => this.users.set(users));
}

// ✅ Option 2: prefer converting to a signal with toSignal() for display;
// use the async pipe when the stream intentionally stays RxJS
protected readonly users$ = this.userApi.list();
// in the template: @for (user of users$ | async; track user.id) { ... }
```

### Common operators

```typescript
import { map, filter, switchMap, debounceTime, distinctUntilChanged, catchError } from 'rxjs';

// Search with debounce
this.searchTerm$
  .pipe(
    debounceTime(300),
    distinctUntilChanged(),
    switchMap(term => this.userApi.search(term)),
    catchError(err => {
      console.error(err);
      return of([]);
    }),
  )
  .subscribe(users => this.users.set(users));
```

---

## Routing

### Standalone routes

```typescript
// app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: 'users', pathMatch: 'full' },
  {
    path: 'users',
    loadChildren: () => import('./features/user/user.routes').then(m => m.userRoutes),
  },
  {
    path: '**',
    loadComponent: () => import('./pages/not-found/not-found.component').then(m => m.NotFoundComponent),
  },
];
```

```typescript
// features/user/user.routes.ts
import { Routes } from '@angular/router';

export const userRoutes: Routes = [
  {
    path: '',
    loadComponent: () => import('./pages/user-list/user-list.component').then(m => m.UserListComponent),
  },
  {
    path: ':id',
    loadComponent: () => import('./pages/user-detail/user-detail.component').then(m => m.UserDetailComponent),
  },
];
```

- ✅ Lazy loading by default (`loadComponent`, `loadChildren`)
- ✅ Routes co-located within the feature (`user.routes.ts`)
- ❌ No more RouterModule.forChild()

### Functional Guards and Resolvers

```typescript
import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    return true;
  }

  router.navigate(['/login']);
  return false;
};
```

Usage:

```typescript
{ path: 'users', canActivate: [authGuard], loadComponent: ... }
```

---

## Recommended structure

```
frontend/src/
├── app/
│   ├── core/                            ← Singleton application services
│   │   ├── auth/
│   │   ├── http-interceptors/
│   │   └── error-handler/
│   ├── shared/                          ← Shared components/pipes
│   │   ├── ui/
│   │   └── pipes/
│   ├── features/                        ← One feature = one folder
│   │   ├── user/
│   │   │   ├── pages/                   ← Routed components
│   │   │   ├── components/              ← Presentation
│   │   │   ├── services/                ← API + local state
│   │   │   ├── models/                  ← Types
│   │   │   └── user.routes.ts
│   │   └── order/
│   ├── app.component.ts
│   ├── app.config.ts                    ← Global configuration
│   └── app.routes.ts
├── environments/
│   ├── environment.ts
│   └── environment.prod.ts
└── main.ts
```

---

## Global configuration

```typescript
// app.config.ts
import { ApplicationConfig, provideZonelessChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { routes } from './app.routes';
import { authInterceptor } from './core/http-interceptors/auth.interceptor';
import { errorInterceptor } from './core/http-interceptors/error.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor, errorInterceptor])),
  ],
};
```

Note: on Angular 21+, new apps are zoneless by default — no change-detection provider is needed at all.

Legacy variant (zone.js projects only, not yet migrated to zoneless):

```typescript
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    // ...
  ],
};
```

---

## Tests

See `11-tests-strategy.md` for details. In short:
- Vitest is the default unit-test runner for new projects since Angular 21; Karma is deprecated. On existing projects, keep whichever runner is in place (Karma/Jasmine or Jest) — do not migrate the runner inside a feature
- TestBed for components
- HttpTestingController for HTTP services
- Cypress for E2E

---

## Anti-patterns to ban

- ❌ `any` everywhere
- ❌ Subscribe without unsubscribe
- ❌ Business logic in the template
- ❌ Direct DOM manipulation (`document.querySelector`)
- ❌ Direct access to `localStorage`/`sessionStorage` (go through a service)
- ❌ Components > 300 lines (split them up)
- ❌ Services that mix HTTP + state + transformation
- ❌ NgModules for new components (standalone)
- ❌ Hard-coded API URLs scattered around (centralize)
- ❌ No HTTP error handling (always `catchError`)
- ❌ Object/array mutations (always immutable: `.update()`, spread, etc.)
