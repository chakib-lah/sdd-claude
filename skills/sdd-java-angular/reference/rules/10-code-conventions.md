# Code Conventions — Spring Boot + Angular

> **Layer 2 — Specific to the Java/Spring Boot backend + Angular frontend stack.**  
> This rule covers both sides. For details, see also `jpa-conventions.md`, `angular-conventions.md`, `api-contracts.md`.

---

## Target versions (adapt per project)

### Backend
- **Java**: 25 LTS recommended (21 LTS common, 17 LTS minimum for legacy)
- **Spring Boot**: 4.1.x recommended for new projects (Spring Framework 7), 3.5.x for maintenance, 3.3.x legacy
- **Build tool**: Gradle 9+ (wrapper committed) with `dependencyLocking` enabled and `gradle.lockfile` committed — OR Maven 3.9+
- **Hibernate ORM**: 6.6+
- **Mapping / boilerplate**: MapStruct + Lombok
- **API documentation**: springdoc-openapi 2.x (Spring Boot 3.x) / 3.x (Spring Boot 4.x)

### Frontend
- **Angular**: 17+ minimum (20+ recommended; zoneless is the default since Angular 21)
- **TypeScript**: 5.x+
- **Node**: 20.x or 22.x LTS
- **Style/UI**: adapt as needed (Material, PrimeNG, Tailwind, custom)

---

## Spring Boot backend — Mandatory rules

> Condensed here. For the full backend detail, see the `sdd-java-backend` skill's rules.

### Constructor injection only

```java
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
}
```

- ✅ `private final` fields + constructor — the only style accepted on new code
- ❌ No field injection (`@Autowired` on a field), no setter injection

### Records for DTOs

```java
public record CreateUserRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password
) {}

public record UserResponse(
    Long id,
    String email,
    Instant createdAt
) {
    public static UserResponse fromEntity(User user) {
        return new UserResponse(user.getId(), user.getEmail(), user.getCreatedAt());
    }
}
```

DTOs are **immutable**: always Java records, never mutable classes with setters.
Public methods that may not find a result return `Optional<T>`, never `null`.

### Thin controllers + ProblemDetail

```java
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable Long id) {
        return userService.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        return userService.create(request);
    }
}
```

Errors are formatted uniformly as RFC 9457 `ProblemDetail` by one shared
`@RestControllerAdvice` — never ad-hoc JSON error bodies per controller.

- ❌ No business logic in a controller
- ❌ No repository or `EntityManager` access in a controller
- ✅ The controller orchestrates, the service decides, the repository persists

### Recommended structure (layered / hexagonal)

```
backend/src/main/java/com/example/app/
├── domain/                     ← Pure business logic, no Spring web/JPA imports
│   ├── model/
│   ├── service/                ← Business service interfaces
│   └── repository/             ← Repository interfaces (ports)
├── application/
│   ├── dto/                    ← Request/Response records
│   ├── mapper/                 ← MapStruct mappers
│   └── service/                ← *ServiceImpl implementations
├── infrastructure/
│   ├── persistence/            ← Spring Data repositories, JPA config
│   ├── web/                    ← @RestController, @RestControllerAdvice
│   └── configuration/
└── common/
```

A flat standard Spring layering (`controller/`, `service/`, `repository/`, `entity/`,
`dto/`) is fine for small or existing projects — pick the existing convention and stay
consistent, never mix both layouts in the same module.

### Overriding BOM-managed versions (Gradle)

With the `io.spring.dependency-management` plugin, prefer an `ext` version
property: the BOM reads it and moves the **whole artifact family** together. An
explicit version on a dependency line is honored too, but it pins only that one
artifact — its siblings stay on the BOM version and the family drifts apart.
`constraints` are unreliable with this plugin; `resolutionStrategy.force` works
as a last resort.

```groovy
// ✅ Preferred: the BOM reads this property and aligns every Tomcat artifact
ext["tomcat.version"] = "11.0.6"

// ⚠️ Honored, but pins only this artifact — siblings keep the BOM version
dependencies {
    implementation("org.apache.tomcat.embed:tomcat-embed-core:11.0.6")
}

// ❌ Unreliable with the dependency-management plugin
dependencies {
    constraints { implementation("org.apache.tomcat.embed:tomcat-embed-core:11.0.6") }
}

// 🆘 Last resort — works, but hides the override; document why
configurations.all {
    resolutionStrategy.force("org.apache.tomcat.embed:tomcat-embed-core:11.0.6")
}
```

`gradle.lockfile` is committed and regenerated with `./gradlew dependencies --write-locks`
after any build-file change — never edited by hand.

See `jpa-conventions.md` for details on entities, repositories and migrations.

---

## Angular frontend — Mandatory rules

### Standalone components

```typescript
import { ChangeDetectionStrategy, Component, signal } from '@angular/core';

@Component({
  selector: 'app-user-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-card.component.html',
  styleUrl: './user-card.component.scss',
})
export class UserCardComponent {
  protected readonly loading = signal(false);
}
```

- ✅ `standalone: true` by default (Angular 17+; implicit default since 19)
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
- ✅ `inject()` rather than constructor injection
- ✅ Explicit types on all HTTP requests/responses
- ❌ No `any`

### Signals-first state

For local component state, prefer Signals:

```typescript
import { Component, signal, computed } from '@angular/core';

@Component({ /* ... */ })
export class UserListComponent {
  protected readonly users = signal<UserResponse[]>([]);
  protected readonly searchTerm = signal('');

  protected readonly filteredUsers = computed(() =>
    this.users().filter(u => u.email.includes(this.searchTerm()))
  );
}
```

For state shared between components, prefer Signal Store (`@ngrx/signals`) or a
service exposing Signals. Keep RxJS for event streams and HTTP composition.

### Types — interfaces and unions

```typescript
// API models — mirror the backend records
export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly createdAt: string;  // ISO 8601
}

export type OrderStatus = 'draft' | 'submitted' | 'approved' | 'rejected';
```

- ✅ Interfaces for object models, types for unions/aliases
- ✅ `readonly` on immutable properties
- ❌ Never `any` — use `unknown` if the type is truly unknown

See `angular-conventions.md` for the full details (control flow, inputs/outputs,
routing, interceptors).

---

## Repository layout

Two common shapes — **adapt to what is in place**:

```
# Shape 1: sibling directories (most common)
my-project/
├── backend/            ← Gradle or Maven project
│   ├── build.gradle
│   └── src/
└── frontend/           ← Angular CLI workspace
    ├── angular.json
    └── src/
```

Variants: `back/` + `front/`, `server/` + `client/` — same principle.

```
# Shape 2: single Gradle project embedding the frontend build
my-project/
├── build.gradle        ← Gradle drives npm via a node plugin
├── src/main/java/
└── src/main/webapp/    ← or frontend/ as a Gradle subproject
```

In shape 2 the Angular build output is copied into the Spring Boot static resources
at assembly time. Rules in this document apply identically; only the paths in
commands change.

---

## API conventions between Spring Boot and Angular

### Uniform error format (ProblemDetail)

```json
{
    "type": "about:blank",
    "title": "Validation failed",
    "status": 400,
    "violations": [
        { "field": "email", "message": "Invalid email format" }
    ]
}
```

Backend side: one `@RestControllerAdvice` producing `ProblemDetail`.  
Angular side: an `HttpInterceptor` that parses `ProblemDetail` bodies into a typed
application error.

### Standard HTTP codes

| Code | Usage |
|---|---|
| 200 | Successful read / update |
| 201 | Successful creation |
| 204 | Successful deletion (no body) |
| 400 | Bad Request (malformed payload or validation failure) |
| 401 | Not authenticated |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict (e.g. email already in use) |
| 422 | Semantically invalid request (business rule) |
| 500 | Server error (details in backend logs only) |

See `api-contracts.md` for the OpenAPI contract workflow (springdoc export, type sync).

---

## Cross-cutting naming conventions

### Sync between backend and frontend

**Rule: an API DTO bears exactly the same name on both sides.** A backend record
maps one-to-one to a frontend interface:

| Backend (Java record) | Frontend (TypeScript interface) |
|---|---|
| `UserResponse` | `UserResponse` |
| `CreateUserRequest` | `CreateUserRequest` |
| `OrderSummaryDto` | `OrderSummaryDto` |
| `UserStatus` (enum) | `UserStatus` (union type or enum) |

JPA entities (`User`, `Order`) never cross the API boundary — only records do, so
only records need a frontend twin.

### URLs

The Spring `@RequestMapping` path is the contract; on the Angular side, centralize it:

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
| Java classes / records | `PascalCase` |
| Java methods/variables | `camelCase` |
| Java packages | `lowercase` |
| TypeScript classes/interfaces | `PascalCase` |
| TypeScript variables/functions | `camelCase` |
| TypeScript filenames | `kebab-case.ts` |
| JSON payload keys | `camelCase` (Jackson default, matches record components) |
| URL routes | `kebab-case`: `/api/order-lines/{id}` |

---

## Anti-patterns to ban

### Backend
- ❌ Business logic in Controllers
- ❌ Field injection (`@Autowired` on fields)
- ❌ Mutable DTOs (classes with setters) — use records
- ❌ `@Data` / `@EqualsAndHashCode` / `@ToString` on JPA entities
- ❌ Returning `null` where `Optional<T>` is expected
- ❌ Exposing JPA entities directly in API responses
- ❌ Editing `gradle.lockfile` by hand

### Frontend
- ❌ `any` — use `unknown` if truly unknown
- ❌ Subscribing to an Observable without unsubscribing (memory leak)
- ❌ Business logic in HTML templates
- ❌ Components > 300 lines (split them up)
- ❌ Services that do HTTP + state + transformation (split into several services)
- ❌ Direct access to `localStorage` / `document` (go through an Angular service)

### Integration
- ❌ Inconsistent response format across endpoints (always ProblemDetail on errors)
- ❌ TypeScript types out of sync with the backend records (no OpenAPI sync)
- ❌ Fanciful HTTP codes (always 200 even on error — validation errors return 400 with the uniform ProblemDetail format)
- ❌ Divergent names for the same DTO (`UserResponse` backend vs `UserModel` frontend)
