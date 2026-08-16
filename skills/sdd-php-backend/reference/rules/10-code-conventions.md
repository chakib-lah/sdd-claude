# Code conventions — PHP

> **Layer 2 — Specific to the PHP stack (no framework).**  
> These conventions apply to all new code written in the project.  
> Legacy code is governed by `legacy-rules.md` (brownfield only).

---

## Target PHP version

To adapt per project:
- **PHP**: 8.4 target for new code — 8.1 minimum ; 7.4 acceptable for existing legacy only
- **All new files**: `<?php declare(strict_types=1);` on the first line

## Autoloading

### New code → PSR-4 mandatory

```json
// composer.json
{
  "autoload": {
    "psr-4": {
      "App\\": "src/"
    }
  }
}
```

### Legacy code → tolerate existing `require` but never create new ones

See `legacy-rules.md` for the migration strategy.

## Naming conventions

### Files
- One class per file: `MyClass.php`
- File name = class name
- Special cases (CLI scripts, config files): tolerated in `snake_case.php` but must be commented

### Classes
- `PascalCase`: `UserService`, `OrderRepository`, `EmailValidator`
- No `Class` suffix, no `C` prefix

### Methods and functions
- `camelCase`: `getUserById`, `validateOrder`, `sendEmail`
- Verb first (clear action)
- `is`, `has`, `can` for booleans: `isValid`, `hasPermission`, `canEdit`

### Variables
- `camelCase`: `$userName`, `$orderTotal`
- Explicit names, no abbreviations except obvious ones (`$id`, `$db`)

### Constants
- `UPPER_SNAKE_CASE`: `MAX_RETRIES`, `DEFAULT_TIMEOUT`

### Namespaces
- `PascalCase`: `App\Service\User`, `App\Repository\Order`
- Logical hierarchy: layer / domain / sub-domain

## Typing

### Mandatory on all new code

```php
<?php
declare(strict_types=1);

namespace App\Service\User;

final class UserService
{
    public function __construct(
        private readonly UserRepository $repository,
        private readonly EmailService $emailService,
    ) {
    }

    public function findById(int $id): ?User
    {
        return $this->repository->find($id);
    }

    public function createUser(string $email, string $password): User
    {
        // ...
    }
}
```

### Strict rules

- ✅ Type on **all** parameters
- ✅ Return type on **all** methods (`void`, `mixed`, etc. made explicit)
- ✅ `readonly` on constructor-injected properties
- ✅ `final` by default on classes (unless inheritance is explicitly planned)
- ❌ No `mixed` unless truly justified (and commented)
- ❌ No untyped parameter
- ❌ No public method without documentation if it is used outside the file

## Recommended structure

```
src/
├── Service/                ← Business logic
│   ├── User/
│   │   ├── UserService.php
│   │   └── UserServiceInterface.php
│   └── Order/
├── Repository/             ← Data access
│   ├── User/
│   └── Order/
├── Entity/                 ← Business models
│   ├── User.php
│   └── Order.php
├── ValueObject/            ← Immutable value objects
│   ├── Email.php
│   └── Money.php
├── Exception/              ← Business exceptions
│   ├── UserNotFoundException.php
│   └── InvalidOrderException.php
├── Validator/              ← Validators
└── Helper/                 ← Utilities (rare, must be justified)
```

## Best practices

### One responsibility per class

- One class = one reason to change (the S in SOLID)
- If a class exceeds 200 lines, that's a signal to split it
- If a class has > 4 injected dependencies, that's a signal of excessive coupling

### Composition over inheritance

```php
// ❌ Bad: inheritance to share code
class AdminUserService extends UserService { ... }

// ✅ Good: composition
final class AdminUserService
{
    public function __construct(
        private readonly UserService $userService,
        private readonly PermissionChecker $permissionChecker,
    ) {}
}
```

### Constructor injection only

- ✅ All dependencies go through the constructor
- ❌ No setter injection
- ❌ No retrieval through a static factory (`UserFactory::create()`)
- ❌ No service locator

### Exceptions

```php
// ✅ Explicit business exceptions
throw new UserNotFoundException("User #{$id} not found");

// ❌ Generic exception without context
throw new \Exception("Error");
```

- One business exception per identified error case
- Inherits from the standard PHP exception hierarchy
- Clear message in English (for logs)

### No global variables in new code

- ❌ `global $db;`
- ❌ Direct access to `$_GET`, `$_POST`, `$_SERVER` from a business class
- ✅ Inject a `Request` object or typed parameters

### Documentation

- PHPDoc mandatory on public methods with non-trivial types (generics, callable, etc.)
- No PHPDoc that duplicates native typing:

```php
// ❌ Redundant
/**
 * @param int $id
 * @return User|null
 */
public function findById(int $id): ?User

// ✅ Sufficient
public function findById(int $id): ?User

// ✅ Useful for generics
/**
 * @return array<int, User>
 */
public function findAll(): array
```

## Anti-patterns to ban

- ❌ `eval()` — absolute prohibition
- ❌ `extract()` — unreadable
- ❌ Commented-out dead code (use Git for history)
- ❌ `@error_suppression` — use try/catch
- ❌ SQL concatenation in business code (always via PDO bindings or a helper)
- ❌ `die()` or `exit()` outside an entry point
- ❌ Global functions outside `index.php` or bootstrap (prefer static utility classes at worst)

## Legacy code

For existing legacy code, see:
- `refactoring-guard.md`: rules to avoid breaking what exists
- `legacy-rules.md`: coexistence of legacy and new code
