# Code Conventions — Symfony + Angular

> **Layer 2 — Specific to the Symfony backend + Angular frontend stack.**  
> This rule covers both sides. For details, see also `30-doctrine-conventions.md`, `40-angular-conventions.md`, `50-api-contracts.md`.

---

## Versions and roots — discovered, never edited into this rule

All stack versions and both project roots are **project facts**: read them from the repository when you need them, and never copy them into this Layer-2 rule — it stays byte-identical across projects.

- **Roots**: the backend root is where `composer.json` lives; the frontend root is where `package.json`/`angular.json` live. Never assume they are named `backend/` and `frontend/` — discover them. Trees below shown with `backend/`/`frontend/` roots are **greenfield examples**; on an existing project, substitute the discovered roots.
- **Backend versions**: PHP, Symfony, Doctrine, PHPUnit — from `composer.json`/`composer.lock`. Skill floor: the backend conventions require PHP **8.1+** language features (attributes, enums, `readonly`).
- **Frontend versions**: Angular, TypeScript, Node — from `package.json`/lockfile, `engines`/`.nvmrc`. The modern Angular practices below apply to the extent the **installed** Angular version supports them.
- **UI library**: discovered from `package.json` (Material, PrimeNG, Tailwind, custom…) — never prescribed here.
- **Greenfield defaults**: current PHP 8.x + maintained Symfony (LTS or current); current Angular major, strict TypeScript, active-LTS Node.

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

### Structure — discover before generating

**Brownfield**: inspect the existing structure under the discovered backend root and follow it — never introduce a new tree (DDD or otherwise) during an unrelated feature. Layer 3 (`.claude/rules/project-architecture.md`) may record the durable architecture decision. **Greenfield example**:

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

See `30-doctrine-conventions.md` for details on entities, repositories and migrations.

---

## Angular frontend — Mandatory rules

The modern target for **new** Angular code is: standalone, signals, `inject()`, `OnPush`/zoneless-compatible design, strict typing. Discover the current architecture first (standalone vs NgModules, ZoneJS vs zoneless, selector prefix in `angular.json`): existing NgModule/ZoneJS code is a **brownfield migration state** — preserved during unrelated feature work and migrated only in dedicated tasks. New code adopts the practices below where the installed Angular version and the surrounding architecture support them.

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

- ✅ `standalone: true` by default for new components (Angular 17+; on 19+ standalone is the default and the flag can be omitted)
- ✅ `ChangeDetectionStrategy.OnPush` everywhere (zoneless-compatible)
- ❌ No new NgModules — existing NgModules stay in place until a dedicated migration, never converted wholesale during a feature

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

For state shared between components, discover the project's established strategy first (NgRx, Signal Store, service-based signals, RxJS store, other) and follow it — durable team policy lives in Layer 3. Greenfield default: Signal Store (`@ngrx/signals`) or a service with Signals.

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

### Structure (greenfield example — an existing project's structure is discovered and followed)

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

See `40-angular-conventions.md` for the full details.

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

### Serialization — discovered serializer

The serializer is a **project fact** (Symfony Serializer, JMS Serializer, API Platform serialization…). The groups below are the **Symfony Serializer example** — on a JMS-based project, follow the established JMS annotations instead of adding Symfony groups.

```php
#[Groups(['user:read', 'user:list'])]
private int $id;

#[Groups(['user:read', 'user:write'])]
private string $email;

#[Groups(['user:write'])]
private string $password;  // never in read
```

See `50-api-contracts.md` for details.

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
- ❌ Leftover debug output (`var_dump`, `dump()`, `dd()`)
- ❌ PHPStan suppression (`@suppress`, `@phpstan-ignore`) without a written justification

### Frontend
- ❌ `any` — use `unknown` if truly unknown (HttpClient responses included)
- ❌ `console.log` left in the code
- ❌ Subscribing to an Observable without `takeUntilDestroyed()` or the `async` pipe (memory leak)
- ❌ Direct state mutation (without `.update()` or spread)
- ❌ Business logic in HTML templates
- ❌ Components > 300 lines (split them up)
- ❌ Services that do HTTP + state + transformation (split into several services)
- ❌ Direct access to `localStorage` / `document` (go through an Angular service)

### Integration
- ❌ Inconsistent response format across endpoints
- ❌ TypeScript types out of sync with the backend (no OpenAPI sync)
- ❌ Fanciful HTTP codes (always 200, never 422 on validation)
- ❌ Serialization without groups (everything exposed everywhere)
