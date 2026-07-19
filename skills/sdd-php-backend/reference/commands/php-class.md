---
description: Scaffold a PHP class from a SDD spec, following project conventions
---

# /php-class

**Auxiliary scaffolding command**: create a new PHP class based on the contents of `spec.md` and `plan.md` of the active feature.

## Blocking prerequisites

- An active SDD feature (matching branch)
- `tasks.md` with `status: approved` and an in-progress task that mentions creating this class
- Code conventions available in `.claude/rules/10-code-conventions.md`

## Steps

### 1. Identify the class to create

Ask the user:
- The name of the class to create (PascalCase)
- The target namespace (per the project structure, e.g. `App\Service\User`)
- The class type (service, repository, validator, value object, exception)

### 2. Load the conventions

Read `.claude/rules/10-code-conventions.md` to comply with:
- `strict_types=1` at the top
- `final` by default
- `readonly` on injected properties
- Types on all parameters and return values
- Constructor injection

### 3. Load the SDD context

Read `spec.md` and `plan.md` of the active feature to understand:
- What the responsibility of this class is
- Which dependencies it will have
- Which public interface it exposes

### 4. Check for duplicates

```bash
# The file must not already exist
test -f src/<path>/<ClassName>.php && echo "EXISTS" || echo "OK"
```

If the file exists → refuse and ask whether it's an addition/modification (in which case it's a different task).

### 5. Generate the class

Typical skeleton:

```php
<?php

declare(strict_types=1);

namespace App\<Namespace>;

final class <ClassName>
{
    public function __construct(
        // Dependencies injected as readonly
    ) {
    }

    // Public methods
}
```

Adapt according to the type:

#### Service

```php
<?php

declare(strict_types=1);

namespace App\Service\<Domain>;

final class <Name>Service
{
    public function __construct(
        private readonly <Dependency1> $dep1,
        private readonly <Dependency2> $dep2,
    ) {
    }

    public function <action>(<params>): <returnType>
    {
        // ...
    }
}
```

If the project uses service interfaces, also create `<Name>ServiceInterface.php`.

#### Repository

```php
<?php

declare(strict_types=1);

namespace App\Repository\<Domain>;

use App\Entity\<Entity>;

final class <Name>Repository
{
    public function __construct(
        private readonly \PDO $db,  // or ORM, depending on the project
    ) {
    }

    public function find(int $id): ?<Entity>
    {
        // ...
    }

    public function findBy(array $criteria): array
    {
        // ...
    }
}
```

#### Value Object

```php
<?php

declare(strict_types=1);

namespace App\ValueObject;

final readonly class <Name>
{
    public function __construct(
        public string $value,
    ) {
        // Validation at instantiation
        if (/* invalid */) {
            throw new \InvalidArgumentException('...');
        }
    }
}
```

#### Exception

```php
<?php

declare(strict_types=1);

namespace App\Exception;

final class <Name>Exception extends \RuntimeException
{
    public static function forUser(int $userId): self
    {
        return new self("Error related to user #{$userId}");
    }
}
```

### 6. Display the code and ask for validation

Before writing the file, display the generated content in the chat and ask for confirmation.

### 7. Write the file

Once validated, create the file at the determined path (e.g. `src/Service/User/UserService.php`).

### 8. Suggest the associated test task

```
✅ Class created: src/Service/User/UserService.php

Recommended next action:
- Run /php-test to scaffold the associated test
- Then continue with /sdd-implement for the next task
```

## Stop rules

- **Do not overwrite an existing file**
- **Do not generate the full business logic**: just the skeleton, the content comes via `/sdd-implement`
- **Do not forget `declare(strict_types=1);`**
- **Do not produce legacy code**: this command generates only code that complies with the conventions
