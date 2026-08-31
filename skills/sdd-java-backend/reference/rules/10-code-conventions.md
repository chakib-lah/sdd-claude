# Code conventions — Java / Spring Boot

> **Layer 2 — Specific to the Java/Spring Boot stack.**

---

## Target versions (to adapt per project)

- **Java**: 25 LTS recommended (21 LTS common, 17 LTS minimum for legacy)
- **Spring Boot**: 4.1.x recommended for new projects (Spring Framework 7), 3.5.x for maintenance, 3.3.x legacy
- **Build tool**: Gradle 9+ (wrapper committed) with `dependencyLocking` enabled and `gradle.lockfile` committed (greenfield recommendation — whether locking is enabled is a discovered project fact) — OR Maven 3.9+
- **Hibernate ORM**: 6.6+
- **Mapping / boilerplate**: MapStruct + Lombok
- **API documentation**: springdoc-openapi 2.x (Spring Boot 3.x) / 3.x (Spring Boot 4.x)

## Mandatory rules on all new code

### Constructor injection only

```java
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
}
```

Or with an explicit constructor (equivalent, no Lombok needed):

```java
@Service
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;

    public UserServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
}
```

❌ No field injection (`@Autowired` on a field), no setter injection.
✅ `private final` fields + constructor — the only style accepted on new code.

### Records for DTOs

```java
public record CreateUserRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password,
    String firstName
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

### `Optional<T>` instead of null returns

```java
// ✅ Good
Optional<User> findByEmail(String email);

// ❌ Bad
User findByEmail(String email);  // returns null when absent
```

- Public methods that may not find a result return `Optional<T>`
- Never return `Optional` from a getter of a JPA entity field
- Never pass `Optional` as a method parameter

### Lombok policy

| Annotation | On JPA entities | On other classes |
|---|---|---|
| `@Getter` / `@Setter` | ✅ allowed | ✅ allowed |
| `@RequiredArgsConstructor` | ✅ allowed | ✅ allowed |
| `@Builder` | ✅ allowed | ✅ allowed |
| `@Data` | ❌ forbidden | ⚠️ avoid (prefer records) |
| `@EqualsAndHashCode` | ❌ forbidden | ⚠️ case by case |
| `@ToString` | ❌ forbidden | ⚠️ beware lazy associations |

`@Data`, `@EqualsAndHashCode` and `@ToString` on JPA entities break lazy loading and
Hibernate identity semantics (equals/hashCode based on mutable fields). Write explicit
`equals`/`hashCode` based on the business key or the identifier.

### Annotation processor ordering

Lombok must run **before** MapStruct, otherwise mappers do not see the generated getters:

```groovy
// build.gradle
dependencies {
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'          // BEFORE mapstruct-processor
    annotationProcessor 'org.mapstruct:mapstruct-processor:1.6.3'
    annotationProcessor 'org.projectlombok:lombok-mapstruct-binding:0.2.0'
}
```

```xml
<!-- Maven: same order inside annotationProcessorPaths -->
<path><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId></path>
<path><groupId>org.mapstruct</groupId><artifactId>mapstruct-processor</artifactId></path>
<path><groupId>org.projectlombok</groupId><artifactId>lombok-mapstruct-binding</artifactId></path>
```

### Null-safety (Spring Boot 4 projects)

Spring Framework 7 adopts **JSpecify**. On Boot 4 projects:

```java
// package-info.java
@NullMarked
package com.example.app.domain;

import org.jspecify.annotations.NullMarked;
```

- `@NullMarked` at package level: everything is non-null by default
- `@Nullable` only on the exceptions that may genuinely be null

## Target architecture

### Layered / hexagonal structure (recommended for new projects)

```
com.example.app/
├── domain/                     ← Pure business logic, no Spring web/JPA imports
│   ├── model/                  ← Business entities / aggregates
│   ├── service/                ← Business service interfaces
│   ├── repository/             ← Repository interfaces (ports)
│   └── exception/              ← Business exceptions
├── application/                ← Use-case orchestration
│   ├── dto/                    ← Request/Response records
│   ├── mapper/                 ← MapStruct mappers
│   └── service/                ← *ServiceImpl implementations
├── infrastructure/             ← Technical details (adapters)
│   ├── persistence/            ← Spring Data repositories, JPA config
│   ├── web/                    ← @RestController, @RestControllerAdvice
│   └── configuration/          ← @Configuration classes
└── common/                     ← Cross-cutting
    ├── exception/              ← Global error handling
    └── utils/
```

### Standard Spring layering (alternative for small/existing projects)

```
com.example.app/
├── controller/                 ← Thin, delegating only
├── service/                    ← Interfaces + implementations
├── repository/                 ← Spring Data interfaces
├── entity/                     ← JPA entities
├── dto/                        ← Request/Response records
├── mapper/                     ← MapStruct mappers
├── exception/                  ← Business exceptions + handler
└── config/                     ← @Configuration classes
```

### Feature-first packaging (variant used by the scaffolding command examples)

```
com.example.app.<feature>/          ← e.g. com.example.app.user
├── domain/                         ← Entities, business rules for the feature
├── application/                    ← Services, mappers
└── api/                            ← Controller
    ├── request/                    ← Input DTO records
    └── response/                   ← Output DTO records
```

To adapt to whatever is already in place in the project. Never mix layouts in
the same module: pick the existing convention and stay consistent.

## Naming conventions

### Standard suffixes

| Concept | Suffix | Example |
|---|---|---|
| Business service interface | `Service` | `UserService`, `OrderService` |
| Service implementation | `ServiceImpl` | `UserServiceImpl` |
| Repository | `Repository` | `UserRepository` |
| Controller | `Controller` | `UserController` |
| Input DTO (record) | `Request` | `CreateUserRequest` |
| Output DTO (record) | `Response`, `Dto` | `UserResponse`, `UserSummaryDto` |
| MapStruct mapper | `Mapper` | `UserMapper` |
| Exception | `Exception` | `UserNotFoundException` |

### Repository methods

```java
Optional<User> findById(Long id);                       // by PK (inherited)
Optional<User> findByEmail(String email);               // by unique criterion
List<User> findByStatus(UserStatus status);             // by business criterion
List<User> findByCreatedAtBetween(Instant from, Instant to);
```

Prefer derived query methods or explicit `@Query` named per use case over generic,
untyped lookups scattered across callers.

## Controllers

### Golden rule: thin controllers

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

❌ No business logic in a controller
❌ No repository or `EntityManager` access in a controller
❌ No inline JPQL/Criteria query in a controller
✅ The controller orchestrates, the service decides, the repository persists

### Uniform error format (RFC 9457 `ProblemDetail`)

One shared `@RestControllerAdvice` for the whole application:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UserNotFoundException.class)
    public ProblemDetail handleNotFound(UserNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource not found");
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation failed");
        problem.setProperty("violations", ex.getFieldErrors().stream()
            .map(err -> Map.of("field", err.getField(), "message", err.getDefaultMessage()))
            .toList());
        return problem;
    }
}
```

### Exception → HTTP mapping

| Exception | HTTP |
|---|---|
| `*NotFoundException` | 404 |
| `*AlreadyExistsException` | 409 |
| `MethodArgumentNotValidException`, `*ValidationException` | 400 |
| `*UnauthorizedException`, `AuthenticationException` | 401 |
| `*ForbiddenException`, `AccessDeniedException` | 403 |
| Other business `RuntimeException` | 400 |
| Unhandled exception | 500 (generic message, details in logs only) |

## Build conventions

### Overriding BOM-managed versions (Gradle + `io.spring.dependency-management`)

With the `io.spring.dependency-management` plugin, an explicit version on a
dependency line **is** honored (the plugin's default `overriddenByDependencies=true`),
but it only pins that single artifact — sibling artifacts of the same family stay on
the BOM version. `constraints` are unreliable for downgrading a BOM-managed version
under this plugin, and `resolutionStrategy.force` works but is a heavy last resort.
The recommended mechanism is the `ext["<family>.version"]` property, because it moves
the **whole artifact family** consistently:

```groovy
// ✅ Works: the BOM reads this property
ext["tomcat.version"] = "11.0.6"
ext["jackson-bom.version"] = "2.18.3"

// ⚠️ Unreliable for downgrades under the dependency-management plugin
dependencies {
    constraints { implementation("org.apache.tomcat.embed:tomcat-embed-core:11.0.6") }
}
```

Maven equivalent: override the version property in `<properties>` **before** the
Spring Boot parent resolves it:

```xml
<properties>
    <tomcat.version>11.0.6</tomcat.version>
</properties>
```

### Dependency locking (Gradle — greenfield recommendation, discovered state)

Whether locking is enabled is a **project fact** (`dependencyLocking` in the build, `gradle.lockfile` present) — never enable it silently during unrelated work. Greenfield setup:

```groovy
dependencyLocking {
    lockAllConfigurations()
}
```

**Where locking is enabled**:
- `gradle.lockfile` is committed and regenerated with `./gradlew dependencies --write-locks`
- Never edit `gradle.lockfile` by hand (see `.claude/rules/12-quality-gates.md`)

### Spring Boot 4 modularization

Spring Boot 4 splits several formerly auto-configured features into dedicated
starters. When upgrading, features that "disappear" usually just need an explicit
starter added to the build file — check the migration notes before debugging.

### Configuration profiles

- `application.yml`: shared defaults, no environment-specific values
- `application-dev.yml`: local development (local DB, verbose logging)
- `application-ci.yml`: CI pipeline (test containers, random ports)
- Secrets come from environment variables, never from committed YAML

## Anti-patterns to ban

- ❌ Business logic in controllers
- ❌ Field injection (`@Autowired` on fields) — constructor injection only
- ❌ `spring.jpa.hibernate.ddl-auto=update` outside local sandboxes (use versioned migrations)
- ❌ Mutable DTOs (classes with setters) — use records
- ❌ `@Data` / `@EqualsAndHashCode` / `@ToString` on JPA entities
- ❌ Returning `null` where `Optional<T>` is expected
- ❌ Catching bare `Exception` or swallowing exceptions (`catch (Exception e) {}`)
- ❌ Editing `gradle.lockfile` by hand
- ❌ `git commit --no-verify`
- ❌ `System.out.println` for logging (use SLF4J)
- ❌ Injecting `@Value` strings everywhere (group them in `@ConfigurationProperties` records)
