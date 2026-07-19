---
description: Scaffold a Symfony service (interface + implementation) from a SDD spec
---

# /symfony-service

**Auxiliary scaffolding command**: create a Symfony service with its interface, ready to be autowired.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation of the service
- Conventions available: `.claude/rules/10-code-conventions.md`

## Steps

### 1. Identify the service to create

Ask for:
- Service name (PascalCase, `Service` suffix or CQRS variant `Handler`)
- Functional domain: `User`, `Order`, `Certificate`, etc.
- Create an interface: yes (recommended) or no

### 2. Load the SDD context

Read `spec.md` (Design section → Services involved) to retrieve:
- Responsibility of the service (a single one)
- Dependencies to inject
- Expected public methods
- Business exceptions to throw

### 3. Load the conventions

Read `.claude/rules/10-code-conventions.md` to comply with:
- `strict_types=1`
- `final` by default
- `readonly` on injected dependencies
- Constructor injection only
- Strict typing everywhere

### 4. Check for duplicates

```bash
test -f src/Service/<Domain>/<Name>Service.php && echo "EXISTS" || echo "OK"
```

### 5. Generate the interface (if requested)

```php
<?php

declare(strict_types=1);

namespace App\Service\<Domain>;

interface <Name>ServiceInterface
{
    public function <method1>(<params>): <return>;
    public function <method2>(<params>): <return>;
    // ...
}
```

### 6. Generate the implementation

```php
<?php

declare(strict_types=1);

namespace App\Service\<Domain>;

use App\Entity\<Entity>;
use App\Repository\<Entity>Repository;
use App\Exception\<EntityNotFound>Exception;
use Psr\Log\LoggerInterface;

final class <Name>Service implements <Name>ServiceInterface
{
    public function __construct(
        private readonly <Entity>Repository $repository,
        private readonly LoggerInterface $logger,
    ) {
    }

    public function <method1>(<params>): <return>
    {
        // Skeleton to implement via /sdd-implement
        // ...
    }
}
```

### 7. If no interface is requested

Generate the `final` service directly without `implements`:

```php
<?php

declare(strict_types=1);

namespace App\Service\<Domain>;

final class <Name>Service
{
    public function __construct(
        // readonly dependencies
    ) {
    }

    // Public methods
}
```

### 8. Identify the exceptions to create

If the spec mentions business error cases that do not yet have a dedicated exception, propose creating them:

```php
<?php

declare(strict_types=1);

namespace App\Exception;

final class <Entity>NotFoundException extends \RuntimeException
{
    public static function withId(int $id): self
    {
        return new self("<Entity> #{$id} not found");
    }
}
```

### 9. Service configuration (if needed)

Check in `config/services.yaml`:
- Whether autowiring works for this service (the default case)
- Whether explicit configuration is needed (parameters, tags)

For the vast majority of services, **no manual configuration is required**: Symfony autowires automatically.

If configuration is needed (custom tag, constant parameter, etc.), propose the `services.yaml` diff.

### 10. Display and validate

Before writing, display in the chat:
- Interface (if created)
- Service implementation
- Exceptions to create (if applicable)
- Any changes to `services.yaml`

Ask for confirmation.

### 11. Write the files

- `src/Service/<Domain>/<Name>ServiceInterface.php` (if interface)
- `src/Service/<Domain>/<Name>Service.php`
- `src/Exception/<Entity><Reason>Exception.php` (if applicable)

### 12. Announce

```
✅ Service created: src/Service/<Domain>/<Name>Service.php
✅ Interface created: src/Service/<Domain>/<Name>ServiceInterface.php (if applicable)
✅ Exception(s) created: src/Exception/...

Note: Symfony autowiring is active, no manual config needed.

Next steps:
- /symfony-test to scaffold the unit tests
- /sdd-implement to fill in the business logic
```

## Stop rules

- **Never overwrite an existing file**
- **Do not fill in the business logic**: that is the role of `/sdd-implement`
- **Always inject via the constructor** (never via setter)
- **Always use `readonly`** on injected dependencies
- **Always use `final`** unless explicit inheritance is planned
- **Do not forget `declare(strict_types=1);`**
- **If a responsibility exceeds the boundaries of the intended service**, suggest splitting into several services rather than creating a God service
