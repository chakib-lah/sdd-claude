# Code Conventions — Symfony + Angular

> **Layer 2 — Specific to the Symfony backend + Angular frontend stack.**  
> This rule covers both sides. For details, see also `doctrine-conventions.md`, `angular-conventions.md`, `api-contracts.md`.

---

## Target versions (adapt per project)

### Backend
- **PHP**: 8.1+ (8.2 or 8.3 recommended)
- **Symfony**: 6.4 LTS or 7.x
- **Doctrine ORM**: 3.x
- **PHPUnit**: 10.x or 11.x

### Frontend
- **Angular**: 17+ (18+ recommended for stable Signals)
- **TypeScript**: 5.x
- **Node**: 20.x LTS (active LTS)
- **Style/UI**: adapt as needed (Material, PrimeNG, Tailwind, custom)

---

## Symfony backend — Mandatory rules

### File header

```php
<?php

declare(strict_types=1);

namespace App\<Layer>\<Domain>;
```

### Classes

- `final` by default
- `readonly` on injected properties
- PSR-12 (PHP-CS-Fixer)

### Strict typing

- Types on all parameters and return values
- No `mixed` without justification
- Generics via PHPDoc for arrays: `@return list<User>`

### Constructor injection only

```php
final class UserService
{
    public function __construct(
        private readonly UserRepository $repository,
        private readonly LoggerInterface $logger,
    ) {
    }
}
```

### Recommended structure

```
backend/
├── src/
│   ├── Controller/         ← Thin, delegating
│   ├── Entity/             ← Doctrine models
│   ├── Repository/         ← Data access
│   ├── Service/            ← Business logic
│   ├── DTO/
│   │   ├── Request/        ← Incoming payloads
│   │   └── Response/       ← Output format
│   ├── Exception/
│   └── EventListener/
└── tests/
    ├── Unit/
    ├── Integration/
    └── Functional/
```

### Thin controllers, Single Action

```php
#[Route('/api/users/{id}', methods: ['GET'])]
final class GetUserController
{
    public function __construct(private readonly UserService $service) {}

    public function __invoke(int $id): JsonResponse
    {
        $user = $this->service->find($id);
        if ($user === null) {
            throw new NotFoundHttpException("User #{$id} not found");
        }
        return new JsonResponse(UserResponse::fromUser($user), Response::HTTP_OK);
    }
}
```

### Immutable, typed DTOs

```php
final readonly class CreateUserRequest
{
    public function __construct(
        public string $email,
        public string $password,
    ) {}
}

final readonly class UserResponse
{
    public function __construct(
        public int $id,
        public string $email,
    ) {}

    public static function fromUser(User $user): self
    {
        return new self($user->getId(), $user->getEmail());
    }
}
```

See `doctrine-conventions.md` for details on entities, repositories and migrations.

---

## Angular frontend — Mandatory rules

### Standalone components

```typescript
import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-card.component.html',
  styleUrl: './user-card.component.scss',
})
export class UserCardComponent {
  protected readonly loading = signal(false);
}
```

- ✅ `standalone: true` by default (Angular 17+)
- ✅ `ChangeDetectionStrategy.OnPush` everywhere
- ❌ No more NgModules for new components

### Services

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

  create(payload: CreateUserRequest): Observable<UserResponse> {
    return this.http.post<UserResponse>(this.baseUrl, payload);
  }
}
```

- ✅ `providedIn: 'root'` (application-wide singleton)
- ✅ `inject()` rather than constructor injection (Angular 14+)
- ✅ Explicit types on all HTTP requests/responses
- ❌ No `any`

### Signals (Angular 17+) or classic RxJS

For local component state, prefer Signals:

```typescript
import { Component, signal, computed } from '@angular/core';

@Component({ /* ... */ })
export class UserListComponent {
  protected readonly users = signal<User[]>([]);
  protected readonly searchTerm = signal('');
  
  protected readonly filteredUsers = computed(() =>
    this.users().filter(u => u.email.includes(this.searchTerm()))
  );
}
```

For state shared between components, prefer Signal Store (`@ngrx/signals`) or a service with Signals.

### Types — interfaces and types

```typescript
// API models
export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly createdAt: string;  // ISO 8601
}

export interface CreateUserRequest {
  readonly email: string;
  readonly password: string;
}

// Unions
export type OrderStatus = 'draft' | 'submitted' | 'approved' | 'rejected';
```

- ✅ Interfaces for object models
- ✅ Types for unions, aliases
- ✅ `readonly` on immutable properties
- ❌ Never `any` — use `unknown` if the type is truly unknown

### Recommended structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── features/                    ← One feature = one folder
│   │   │   ├── user/
│   │   │   │   ├── pages/               ← Routed components
│   │   │   │   │   └── user-list/
│   │   │   │   │       ├── user-list.component.ts
│   │   │   │   │       ├── user-list.component.html
│   │   │   │   │       ├── user-list.component.scss
│   │   │   │   │       └── user-list.component.spec.ts
│   │   │   │   ├── components/           ← Presentation
│   │   │   │   ├── services/             ← API + state
│   │   │   │   ├── models/               ← Types
│   │   │   │   └── user.routes.ts
│   │   │   └── order/
│   │   ├── shared/                       ← Shared components/services
│   │   ├── core/                         ← Application services (auth, http interceptor)
│   │   └── app.routes.ts
│   ├── environments/
│   └── main.ts
```

See `angular-conventions.md` for the full details.

---

## API conventions between Symfony and Angular

### Uniform error format

```json
{
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "violations": [
        { "field": "email", "message": "Invalid email format" }
    ]
}
```

Symfony side: an EventListener that formats exceptions.  
Angular side: an HttpInterceptor that parses errors.

### Standard HTTP codes

| Code | Usage |
|---|---|
| 200 | Successful read / update |
| 201 | Successful creation |
| 204 | Successful deletion (no body) |
| 400 | Bad Request (malformed payload) |
| 401 | Not authenticated |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict (e.g. email already in use) |
| 422 | Validation failed |
| 500 | Server error (logs on the backend side) |

### Symfony serialization — Groups

```php
#[Groups(['user:read', 'user:list'])]
private int $id;

#[Groups(['user:read', 'user:write'])]
private string $email;

#[Groups(['user:write'])]
private string $password;  // never in read
```

See `api-contracts.md` for details.

---

## Cross-cutting naming conventions

### Sync between backend and frontend

An entity must bear the same name in both worlds:

| Backend | Frontend |
|---|---|
| `App\Entity\User` | `User` (TypeScript interface) |
| `App\DTO\Request\CreateUserRequest` | `CreateUserRequest` (interface) |
| `App\DTO\Response\UserResponse` | `UserResponse` (interface) |

### Routes vs URLs

The Symfony route name is internal; on the Angular side, use URLs:

```typescript
// ❌ Bad: hard-coded URL scattered around
this.http.get('/api/users/1');

// ✅ Good: centralized in a service or a constant
private readonly baseUrl = '/api/users';
this.http.get(`${this.baseUrl}/${id}`);
```

### Casing

| Layer | Convention |
|---|---|
| PHP classes | `PascalCase` |
| PHP methods/variables | `camelCase` |
| TypeScript classes | `PascalCase` |
| TypeScript variables/functions | `camelCase` |
| TypeScript filenames | `kebab-case.ts` |
| JSON payload keys | `camelCase` (consistent with PHP DTOs) |
| URL routes | `kebab-case`: `/api/order-lines/{id}` |

---

## Anti-patterns to ban

### Backend
- ❌ Business logic in Controllers
- ❌ Inline DQL outside Repositories
- ❌ EntityManager in Controllers
- ❌ `any` or untyped DTOs
- ❌ Generic public setters on entities

### Frontend
- ❌ `any` — use `unknown` if truly unknown
- ❌ Subscribing to an Observable without unsubscribing (memory leak)
- ❌ Business logic in HTML templates
- ❌ Components > 300 lines (split them up)
- ❌ Services that do HTTP + state + transformation (split into several services)
- ❌ Direct access to `localStorage` / `document` (go through an Angular service)

### Integration
- ❌ Inconsistent response format across endpoints
- ❌ TypeScript types out of sync with the backend (no OpenAPI sync)
- ❌ Fanciful HTTP codes (always 200, never 422 on validation)
- ❌ Serialization without groups (everything exposed everywhere)
