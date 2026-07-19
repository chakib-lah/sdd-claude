---
description: Scaffold a Doctrine entity with migration from a SDD spec
---

# /symfony-entity

**Auxiliary scaffolding command**: create a Doctrine entity with its associated migration and repository.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation/modification of this entity
- Conventions available: `.claude/rules/10-code-conventions.md`, `.claude/rules/doctrine-conventions.md`

## Steps

### 1. Identify the entity to create

Ask for:
- Entity name (PascalCase, singular): `User`, `Order`, `Certificate`
- Functional domain (if DDD): `User`, `Order`, etc.

### 2. Load the SDD context

Read `spec.md` (Design section → Entity/entities / DB changes) to retrieve:
- List of fields with their types and constraints
- Relations with other entities
- Required indexes
- Unique constraints

### 3. Load the Doctrine conventions

Read `.claude/rules/doctrine-conventions.md` to comply with:
- PHP 8+ attribute format
- `DateTimeImmutable` for dates
- Explicit constructor with invariants
- No generic public setters
- Collection initialization

### 4. Check for duplicates

```bash
test -f src/Entity/<EntityName>.php && echo "EXISTS" || echo "OK"
```

If the file exists → ask whether this is a modification (re-read the spec for the exact changes) or whether the name is wrong.

### 5. Generate the entity

Typical skeleton:

```php
<?php

declare(strict_types=1);

namespace App\Entity;

use App\Repository\<EntityName>Repository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: <EntityName>Repository::class)]
#[ORM\Table(name: '<table_name>')]
// #[ORM\Index(name: 'idx_<table>_<col>', columns: ['<col>'])]   ← if needed
// #[ORM\UniqueConstraint(name: 'uq_<table>_<col>', columns: ['<col>'])]  ← if needed
final class <EntityName>
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    private ?int $id = null;

    // Fields typed according to the spec

    #[ORM\Column(type: 'datetime_immutable')]
    private \DateTimeImmutable $createdAt;

    public function __construct(/* required params according to the invariants */)
    {
        // Initialize required fields
        $this->createdAt = new \DateTimeImmutable();
        // Initialize collections: $this->relations = new ArrayCollection();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    // Getters according to the spec
    // Setters ONLY if the field is meant to change (otherwise remove them)
}
```

### 6. Generate the associated Repository

```php
<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\<EntityName>;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<<EntityName>>
 */
final class <EntityName>Repository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, <EntityName>::class);
    }

    // Named query methods (according to the spec)
    // Ex: findByEmail(string $email): ?<EntityName>
}
```

### 7. Generate the Doctrine migration

```bash
# Automatic mode (Symfony generates the diff)
php bin/console make:migration

# Check the generated file (typically Migrations/Version<YmdHis>.php)
```

Verify that the generated migration contains:
- ✅ Complete `up()` (added columns, constraints, indexes)
- ✅ Complete `down()` (reversibility)
- ✅ No unexpected changes to other tables

If `down()` is missing, complete it manually.

### 8. Display and validate

Before writing the files, display in the chat:
- Entity content
- Repository content
- Migration content
- List of impacted relations (other entities to modify?)

Ask for confirmation.

### 9. Write the files

- `src/Entity/<EntityName>.php`
- `src/Repository/<EntityName>Repository.php`
- `src/Migrations/Version<YmdHis>.php`

### 10. Test the migration

```bash
# Locally
php bin/console doctrine:migrations:migrate --env=dev --no-interaction

# Then test reversibility
php bin/console doctrine:migrations:migrate prev --env=dev --no-interaction
php bin/console doctrine:migrations:migrate --env=dev --no-interaction
```

### 11. Announce

```
✅ Entity created: src/Entity/<EntityName>.php
✅ Repository created: src/Repository/<EntityName>Repository.php
✅ Migration created: src/Migrations/Version<YmdHis>.php

Migration tested:
  - up(): ✅
  - down(): ✅
  - Reversibility: ✅

Next steps:
- Run /symfony-test to scaffold the tests
- Then /sdd-implement for the next task
```

## Stop rules

- **Never overwrite an existing file**
- **Always generate the repository alongside the entity**
- **Always generate a migration** if the entity is new or modified
- **Always implement `down()`** in the migration
- **Do not add a setter on every field**: only on those that are meant to change
- **Do not add business logic to the entity** except trivial invariants
- **Do not forget `declare(strict_types=1);`**
