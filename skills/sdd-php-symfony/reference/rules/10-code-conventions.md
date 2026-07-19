# Code conventions — PHP / Symfony

> **Layer 2 — Specific to the PHP/Symfony stack.**

---

## Target versions (to adapt per project)

- **PHP**: 8.1+ (recommended 8.2 or 8.3)
- **Symfony**: 6.4 LTS or 7.x
- **Doctrine ORM**: 3.x
- **PHPUnit**: 10.x or 11.x

## Mandatory rules on all new code

### File header

```php
<?php

declare(strict_types=1);

namespace App\<Layer>\<Domain>;
```

### Classes

- `final` by default (unless inheritance is explicit and justified)
- `readonly` on constructor-injected properties
- PSR-12 for formatting (handled by PHP-CS-Fixer)

### Strict typing

- Type on **all** parameters
- Return type on **all** methods (never omit `void`)
- No `mixed` unless truly justified
- No bare `array` without specifying the type via generic PHPDoc

```php
/**
 * @return list<User>
 */
public function findAll(): array
```

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

❌ No setter injection, no service locator, no retrieval via `$container->get()` outside the bootstrap.

## Target architecture

### Adapted standard Symfony structure

```
src/
├── Controller/                 ← Thin, delegating only
├── Entity/                     ← Doctrine models
├── Repository/                 ← Data access
├── Service/                    ← Business logic
├── Validator/                  ← Custom validators
├── EventListener/              ← Event subscribers
├── DTO/                        ← Data Transfer Objects
├── ValueObject/                ← Immutable value objects
├── Exception/                  ← Business exceptions
├── Form/                       ← Symfony FormTypes (if Forms are used)
└── Twig/                       ← Twig extensions (if Twig is used)
```

### DDD structure (alternative for large projects)

```
src/
├── Domain/                     ← Pure business logic
│   ├── User/
│   │   ├── Entity/
│   │   ├── Repository/         ← Interfaces only
│   │   ├── Service/
│   │   ├── ValueObject/
│   │   └── Exception/
│   └── Order/
├── Application/                ← Use cases / Command Handlers
│   ├── User/
│   │   ├── Command/
│   │   ├── Query/
│   │   └── Handler/
│   └── Order/
└── Infrastructure/             ← Technical details
    ├── Doctrine/
    │   └── Repository/         ← Doctrine implementations
    ├── Symfony/
    └── Http/
```

To adapt to whatever is already in place in the project.

## Naming conventions

### Standard suffixes

| Concept | Suffix | Example |
|---|---|---|
| Business service | `Service` | `UserService`, `OrderService` |
| Repository | `Repository` | `UserRepository` |
| Validator | `Validator` | `EmailValidator` |
| Input/output DTO | `DTO`, `Request`, `Response` | `CreateUserRequest`, `UserResponse` |
| Value Object | (no suffix) | `Email`, `Money`, `OrderStatus` |
| Exception | `Exception` | `UserNotFoundException` |
| Event | `Event` | `UserRegisteredEvent` |
| Command (CQRS) | `Command` | `CreateUserCommand` |
| Query (CQRS) | `Query` | `GetUserByIdQuery` |
| Handler (CQRS) | `Handler` | `CreateUserHandler` |
| Factory | `Factory` | `UserFactory` |
| Subscriber/Listener | `Subscriber`, `Listener` | `UserRegisteredSubscriber` |

### Repository methods

```php
public function find(int $id): ?User                          // by PK
public function findByEmail(string $email): ?User             // by unique criterion
public function findActiveUsers(): array                       // by business criterion
public function findByDateRange(\DateTimeImmutable $from, \DateTimeImmutable $to): array
```

No generic `findOneBy*` methods exposed: prefer methods named per use case.

## Controllers

### Golden rule: thin controllers

```php
#[Route('/api/users/{id}', methods: ['GET'])]
final class GetUserController
{
    public function __construct(
        private readonly UserService $userService,
    ) {
    }

    public function __invoke(int $id): JsonResponse
    {
        $user = $this->userService->find($id);
        if ($user === null) {
            throw new NotFoundHttpException("User #{$id} not found");
        }
        return new JsonResponse($user, Response::HTTP_OK);
    }
}
```

❌ No business logic in a controller  
❌ No direct EntityManager access in a controller  
❌ No inline Doctrine query (`createQueryBuilder`) in a controller  
✅ The controller orchestrates, the service decides, the repository persists

### Single Action Controllers (recommended)

One controller = one action = one endpoint. Use `__invoke()`.

### Symfony routes via attributes (PHP 8+)

```php
#[Route('/api/users/{id}', methods: ['GET'], name: 'user_get')]
```

❌ No YAML/XML routes for new endpoints.

## Services

### One responsibility per service

```php
// ✅ Good
final class UserRegistrationService
{
    public function register(string $email, string $password): User { ... }
}

final class UserPasswordService
{
    public function changePassword(int $userId, string $newPassword): void { ... }
}

// ❌ Bad: God service
final class UserService
{
    public function register(...) { ... }
    public function changePassword(...) { ... }
    public function deleteAccount(...) { ... }
    public function sendNewsletter(...) { ... }
    public function generateReport(...) { ... }
}
```

### Interfaces

For services injected in several places or potentially mocked in tests:
- Create an interface (`UserServiceInterface`)
- The final implementation (`UserService`)
- Bind in `config/services.yaml` if autowiring does not handle it

For internal services used sporadically, the interface is not mandatory.

## DTOs

### Request DTOs

```php
final readonly class CreateUserRequest
{
    public function __construct(
        public string $email,
        public string $password,
        public ?string $firstName = null,
    ) {
    }
}
```

### Response DTOs

```php
final readonly class UserResponse
{
    public function __construct(
        public int $id,
        public string $email,
        public string $createdAt,  // ISO 8601 string
    ) {
    }

    public static function fromUser(User $user): self
    {
        return new self(
            id: $user->getId(),
            email: $user->getEmail(),
            createdAt: $user->getCreatedAt()->format(\DateTimeInterface::ATOM),
        );
    }
}
```

Rather than untyped arrays, use typed, immutable DTOs.

## Symfony serialization

### Normalization groups

```php
#[ORM\Entity]
final class User
{
    #[Groups(['user:read', 'user:list'])]
    private int $id;

    #[Groups(['user:read', 'user:list', 'user:write'])]
    private string $email;

    #[Groups(['user:write'])]
    private string $password;  // never exposed in read
}
```

Standard groups:
- `<entity>:read`: publicly readable fields
- `<entity>:write`: modifiable fields
- `<entity>:list`: fields in lists (often a subset of `read`)
- `<entity>:detail`: fields in detail views (often a superset of `read`)

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

## Exceptions

### Hierarchy

```php
namespace App\Exception;

abstract class DomainException extends \RuntimeException {}

final class UserNotFoundException extends DomainException
{
    public static function withId(int $id): self
    {
        return new self("User #{$id} not found");
    }
}
```

### HTTP codes

Standard mapping via an EventListener:

| Exception | HTTP |
|---|---|
| `*NotFoundException` | 404 |
| `*AlreadyExistsException` | 409 |
| `*ValidationException` | 422 |
| `*UnauthorizedException` | 401 |
| `*ForbiddenException` | 403 |
| Other `DomainException` | 400 |

## Anti-patterns to ban

- ❌ Business logic in Controllers
- ❌ DQL or QueryBuilder in Controllers
- ❌ Direct access to `$_GET`, `$_POST`, `$_REQUEST` (use the injected `Request`)
- ❌ Static methods that depend on state (except Value Object factories)
- ❌ Hand-rolled singletons (use the Symfony DIC)
- ❌ `EntityManager::flush()` in a controller (delegate to services)
- ❌ Mocking the EntityManager in a unit test (use an integration test with a test DB)
- ❌ Mutable DTOs (always `readonly`)
- ❌ Doctrine YAML/XML annotations for a new entity (use PHP 8 attributes)
