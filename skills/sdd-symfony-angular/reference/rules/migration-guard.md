# Migration Guard — Symfony brownfield

> **Layer 2 — Brownfield-specific (PHP/Symfony).**  
> Rules to avoid breaking the existing system when evolving an established Symfony project.

---

## Fundamental principle

> Any change to an existing entity, service or endpoint must **preserve the current behavior** unless the spec explicitly says otherwise (breaking change accepted and documented).

## Before modifying an existing entity

### 1. Identify all usages

```bash
# The class name
grep -rn "use App\\\\Entity\\\\User" src/ tests/
grep -rn "new User(" src/ tests/

# The methods used
grep -rn "->getEmail()" src/ tests/
grep -rn "->setStatus(" src/ tests/
```

### 2. Read the existing tests

If tests cover the entity, they define the expected behavior. Any break in those tests must be documented.

### 3. Check the exposed public API

If the entity is serialized in an API response, check:
- The serialization groups in use
- The frontend consumers (Angular, mobile, external)
- That the OpenAPI documentation is up to date

## Before modifying an existing service

### 1. Identify all callers

```bash
# Injections of the service
grep -rn "UserService " src/ tests/
grep -rn ": UserService" src/ tests/

# Methods used
grep -rn '->find(' src/ | grep UserService
```

### 2. Preserve the public signature

Unless the spec explicitly says otherwise:

```php
// ❌ Dangerous signature change
- public function find(int $id): ?User
+ public function find(int $id, bool $withRelations = false): ?User

// ✅ Prefer a new method
public function find(int $id): ?User { ... }        // unchanged
public function findWithRelations(int $id): ?User { ... }  // new
```

### 3. If a signature MUST change

Document it as a breaking change:
- Create `breaking-changes.md` in the feature folder
- List all impacted callers
- Include an AC in the spec for updating the callers
- Consider a transition period with `@deprecated`

```php
/**
 * @deprecated since 2.5, use findWithRelations() instead.
 *             Will be removed in 3.0.
 */
public function find(int $id, bool $withRelations = false): ?User
```

## Database migrations

### Every migration must have a reversible `down()`

```php
final class Version20260101120000 extends AbstractMigration
{
    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user ADD COLUMN email_verified_at DATETIME DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user DROP COLUMN email_verified_at');
    }
}
```

### Adding vs removing a column

**Addition**: generally safe if nullable or with a default value.

**Removal**: do it in 2 separate deployments:

1. **Deployment A**:
   - Remove all uses of the column in the code
   - No removal migration yet
   - Deploy
2. **Deployment B** (weeks later):
   - Removal migration
   - Deploy

### Renaming a column

Avoid. If necessary:
1. Add a new column with the new name
2. Migrate the data via a Symfony command
3. Mark the old column `@deprecated` in the code
4. Later, remove the old column (2-step process)

### Type change

Very dangerous. Prefer:
1. Add a new column with the new type
2. Backfill via a command
3. Switch the code over
4. Remove the old column

## Code removal

### Before removing a class, service, or entity

1. Search for all usages:
   - Source code (`grep -r`)
   - Tests
   - Configuration files (`config/services.yaml`, `config/packages/`)
   - Twig templates
   - Symfony commands (`bin/console list`)
   - Cron jobs / scripts
2. If even a single usage exists → do not remove, mark `@deprecated`

### `@deprecated` before final removal

```php
/**
 * @deprecated since 3.0, use NewUserService::register() instead.
 *             Will be removed in 4.0.
 */
final class OldUserService
{
    // ...
}
```

Symfony automatically emits deprecation warnings → visible in the profiler bar and in tests.

## Serialization and API

### Response format

Any change to the API response format is a **breaking change** for consumers.

```php
// ❌ Removing an exposed field
- #[Groups(['user:read'])]
- public string $oldField;

// ✅ Transition strategy
#[Groups(['user:read'])]
public string $oldField;  // kept temporarily

#[Groups(['user:read'])]
public string $newField;  // added in parallel

// Later, once clients have migrated: remove oldField
```

### Normalization groups

Never remove a field from a `read` group without coordinating with the clients.

Adding a field to a `read` group is generally safe (clients ignore unknown fields).

## Mandatory tests when making changes

### Characterization tests before modification

If the code to be modified has no tests, write a test that **captures the current behavior** before modifying it:

```php
/**
 * Characterization: captures the current behavior to detect regressions.
 */
public function testCurrentBehaviorBeforeRefactor(): void
{
    $result = $this->sut->processOrder($legacyData);
    self::assertSame('expected current output', $result);
}
```

### Non-regression tests in the spec

Every AC that modifies existing behavior must have a twin non-regression AC:

```
AC-1: When the user creates an order with the new payload format, 
      the order is saved correctly.

AC-1bis (non-regression): When the user creates an order with the old 
                          payload format, the previous behavior is preserved.
```

## Symfony configuration

### Modifying `config/services.yaml`

```yaml
# Before modifying an alias or an argument
# 1. Identify all services that depend on this alias
# 2. Check that no listener/subscriber uses the old tag
# 3. Test in dev mode AND in prod mode (different cache)
```

### Modifying `config/packages/security.yaml`

🚨 **Particularly sensitive**. Always:
1. Test locally with a full-privilege user
2. Test with a limited user
3. Test the anonymous routes
4. Check the active firewalls

### Modifying `config/routes.yaml`

If a route name changes, every `generateUrl('old_name')` breaks. Prefer adding an alias:

```php
#[Route('/api/users/{id}', name: 'user_get')]
#[Route('/api/users/{id}', name: 'app_user_show', priority: -1)]  // legacy alias
```

## Bundle or Composer dependency

### Before adding a dependency

- Check maintenance status (latest release, open issues)
- Check the license (compatibility with the project)
- Check the size of the installed dependency tree

### Before removing a dependency

- Search for all usages (bundle classes, services, etc.)
- Check the config files (`config/packages/<bundle>.yaml`)
- Check the bundles enabled in `config/bundles.php`

### Upgrading Symfony

Major upgrades:
1. Read the UPGRADE notes of the Symfony project
2. Run `bin/console debug:container --deprecations` before and after
3. Do a full round of tests
4. Consider Rector to automate part of the changes

## SDD brownfield refactor workflow

1. `/sdd-start REFACTOR-XXX-<description>`
2. `/sdd-spec` — always include non-regression AC
3. `/sdd-plan` — progressive strategy (wrapper → delegation → switchover → removal)
4. `/sdd-tasks` — atomic breakdown
5. Before any implementation task: write the characterization tests if missing
6. `/sdd-implement` one task at a time
7. `/sdd-verify` and `/sdd-review` at the end

## Anti-patterns

- ❌ Big rewrite of an entire service in a single commit
- ❌ Modification without prior tests
- ❌ Database migration without `down()`
- ❌ Removing a column and the code that used it in the same deployment
- ❌ Changing a public signature without `@deprecated`
- ❌ Removing a method without an exhaustive search for usages
- ❌ Refactoring mixed with feature work in the same commit
- ❌ "We'll see in production if it breaks" — no, we test first
