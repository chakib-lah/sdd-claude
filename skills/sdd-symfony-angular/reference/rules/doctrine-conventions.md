# Doctrine — Conventions

> **Layer 2 — Specific to Doctrine ORM (PHP/Symfony).**

---

## Target version

- **Doctrine ORM**: 3.x (Doctrine ORM 2.x acceptable for projects in migration)
- **Doctrine DBAL**: 4.x
- **doctrine-bundle**: 2.x

## Entities

### Golden rule: one entity, one responsibility

An entity represents a single business concept. If an entity has more than 15-20 properties, that is usually a sign of poor modeling.

### Entity format (PHP 8+ attributes)

```php
<?php

declare(strict_types=1);

namespace App\Entity;

use App\Repository\UserRepository;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: UserRepository::class)]
#[ORM\Table(name: 'user')]
final class User
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    private ?int $id = null;

    #[ORM\Column(type: 'string', length: 180, unique: true)]
    private string $email;

    #[ORM\Column(type: 'datetime_immutable')]
    private \DateTimeImmutable $createdAt;

    public function __construct(string $email)
    {
        $this->email = $email;
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getEmail(): string
    {
        return $this->email;
    }

    public function getCreatedAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }
}
```

❌ **Stop using YAML, XML or docblock annotations** for new entities.  
❌ **No generic setters** on every field — only create a setter if the field must be able to change.

### Explicit constructor

Prefer a constructor that enforces invariants at instantiation:

```php
// ✅ Good
public function __construct(string $email, string $name)
{
    $this->email = $email;
    $this->name = $name;
    $this->createdAt = new \DateTimeImmutable();
    $this->orders = new ArrayCollection();
}

// ❌ Bad: entity created empty, then filled via setters
$user = new User();
$user->setEmail(...);
$user->setName(...);
```

### Recommended Doctrine types

| PHP | Doctrine | Notes |
|---|---|---|
| `int` | `integer` | |
| `?int` | `integer`, `nullable: true` | |
| `string` | `string`, `length: N` | always specify `length` |
| `string` (long) | `text` | for > 1000 characters |
| `bool` | `boolean` | |
| `\DateTimeImmutable` | `datetime_immutable` | ✅ prefer over `datetime` |
| `\DateTimeImmutable` (date only) | `date_immutable` | |
| `array` | `json` | ❌ avoid `array` (deprecated in ORM 3) |
| PHP 8.1+ Enum | `string` or `integer` + `enumType` | |

### Datetime

Always use `\DateTimeImmutable` rather than `\DateTime`:

```php
#[ORM\Column(type: 'datetime_immutable')]
private \DateTimeImmutable $createdAt;
```

### PHP 8.1+ Enums

```php
enum OrderStatus: string
{
    case Draft = 'draft';
    case Submitted = 'submitted';
    case Approved = 'approved';
    case Rejected = 'rejected';
}

#[ORM\Column(type: 'string', length: 20, enumType: OrderStatus::class)]
private OrderStatus $status;
```

## Repositories

### Extend ServiceEntityRepository

```php
<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<User>
 */
final class UserRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    public function findByEmail(string $email): ?User
    {
        return $this->findOneBy(['email' => $email]);
    }

    /**
     * @return list<User>
     */
    public function findActiveUsers(): array
    {
        return $this->createQueryBuilder('u')
            ->andWhere('u.deletedAt IS NULL')
            ->orderBy('u.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}
```

### Method conventions

| Method | Usage |
|---|---|
| `find(int $id)` | By PK only |
| `findBy<Criterion>(...)` | By business criterion (`findByEmail`, `findByStatus`) |
| `findActive<Entity>s()` | Listing by business filter |
| `findOne...()` | Returns a single entity or null |
| `count<Criterion>(...)` | Counting |
| `existsByEmail(string)` | Existence check |

❌ **No `findAll()`** in application code except in truly justified cases (admin, debug). Prefer methods named after use cases.

❌ **No Repository methods that return anything other than entities** or well-typed scalars (no anonymous associative arrays).

### No DQL/QueryBuilder outside of Repositories

```php
// ❌ Bad: DQL in the service
final class UserService
{
    public function findRecentUsers(): array
    {
        return $this->em->createQuery('SELECT u FROM User u WHERE u.createdAt > :date')
            ->setParameter('date', new \DateTimeImmutable('-30 days'))
            ->getResult();
    }
}

// ✅ Good: DQL in the repository
final class UserRepository extends ServiceEntityRepository
{
    /**
     * @return list<User>
     */
    public function findRecentUsers(int $daysAgo = 30): array
    {
        return $this->createQueryBuilder('u')
            ->andWhere('u.createdAt > :date')
            ->setParameter('date', new \DateTimeImmutable("-{$daysAgo} days"))
            ->getQuery()
            ->getResult();
    }
}

final class UserService
{
    public function getRecentUsers(): array
    {
        return $this->repository->findRecentUsers();
    }
}
```

## Relations

### Explicit cascade only when justified

```php
// ✅ Good: cascade documented in the spec
#[ORM\OneToMany(targetEntity: OrderLine::class, mappedBy: 'order', cascade: ['persist', 'remove'])]
private Collection $lines;
```

❌ **No blind `cascade: ['all']`**: too dangerous.

### Lazy vs Eager

By default, all relations are **lazy** (loaded on demand). Only use `EAGER` in very specific, documented cases.

### Bidirectional vs Unidirectional

- **Bidirectional**: when both entities need to navigate to each other
- **Unidirectional**: the default, simpler to maintain

### Initialize collections in the constructor

```php
public function __construct(string $name)
{
    $this->name = $name;
    $this->orders = new ArrayCollection();  // ← mandatory
}
```

## Migrations

### Doctrine Migrations Bundle

```bash
composer require doctrine/doctrine-migrations-bundle
```

### Rules

- **One migration per schema change** — no giant migrations
- **Always implement `down()`** — reversibility is mandatory
- **Test migrations locally** before committing

```php
final class Version20260101120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add email_verified_at column to user table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user ADD email_verified_at DATETIME DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user DROP email_verified_at');
    }
}
```

### Column removal — always in 2 steps

**Step 1 — Deployment A**:
- Remove all references to the column in the code
- No removal migration yet
- Deploy to Production

**Step 2 — Deployment B (weeks later)**:
- Create the removal migration
- Deploy

This avoids partial deployments that break production.

### Data in migrations

❌ Avoid putting business logic in migrations.  
✅ For initial data (seeds), use **Doctrine fixtures** rather than migrations.  
✅ For complex data transformations during a schema migration, create a dedicated Symfony command invoked after the migration.

## Performance

### Hydration

For simple lists (mass reads), use `ARRAY` hydration:

```php
return $this->createQueryBuilder('u')
    ->select('u.id', 'u.email')
    ->getQuery()
    ->getArrayResult();  // instead of getResult() which hydrates objects
```

### N+1 queries

Always prefetch the relations you use:

```php
// ❌ Bad: N+1
$users = $repository->findAll();
foreach ($users as $user) {
    echo $user->getOrders()->count();  // ← 1 query per user
}

// ✅ Good
$users = $repository->createQueryBuilder('u')
    ->leftJoin('u.orders', 'o')->addSelect('o')
    ->getQuery()
    ->getResult();
```

### Indexes

For any column frequently used in `WHERE`, `JOIN`, `ORDER BY`:

```php
#[ORM\Entity]
#[ORM\Table(name: 'user')]
#[ORM\Index(name: 'idx_user_email', columns: ['email'])]
#[ORM\Index(name: 'idx_user_created_at', columns: ['created_at'])]
final class User { ... }
```

## Anti-patterns to ban

- ❌ Public setters on every field (breaks encapsulation)
- ❌ `Entity::flush()` in the code (that is the Service/Handler's responsibility)
- ❌ Business logic in entities (except trivial invariants)
- ❌ DQL/QueryBuilder in Controllers or Services
- ❌ Unmanaged bidirectional relations (a setOwner method without synchronizing the inverse side)
- ❌ Blind `cascade: ['all']`
- ❌ Migrations without `down()`
- ❌ Removing a column in the same deployment as the code that used it
- ❌ Using `getReference()` without knowing what it does
- ❌ Reading the whole table without pagination (`findAll()` on 1 million rows)
