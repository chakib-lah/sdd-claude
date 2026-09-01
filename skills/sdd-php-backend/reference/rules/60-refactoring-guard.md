# Refactoring Guard — Don't break what exists

> **Layer 2 — Brownfield-specific.**  
> Rules for modifying legacy code without introducing regressions.

---

## Fundamental principle

> Every refactor must be **invisible to the users and callers** of the refactored code.

Unless the spec explicitly says otherwise (breaking change accepted and documented).

## Before any modification of an existing file

### 1. Identify all callers

```bash
# Search for usages of a class or function
grep -r "MyFunction(" src/
grep -r "new MyClass(" src/
grep -r "MyClass::" src/
```

### 2. Read the existing tests

If there are any, understand what they validate. **These tests will be your safety net.**

### 3. If no test exists

**Stop.** Before modifying, write at least one **characterization test** that captures the current behavior:

```php
public function testCharacterizationOfLegacyBehavior(): void
{
    // Capture what the code does TODAY, without judgment
    $result = legacyFunction(42, 'hello');
    self::assertSame('expected current output', $result);
}
```

This test will become obsolete after the refactor, but it lets you detect a regression while you work.

### 4. Identify hidden dependencies

- Global variables used
- Sessions accessed
- Constants defined elsewhere
- Implicit `require`/`include`
- Side effects (logs, file writes)

## Modification rules

### Preserve the public signature

Unless the spec explicitly says to change it:

```php
// ❌ Bad: changing the signature breaks callers
- function getUser($id)
+ function getUser(int $id, bool $withRelations = false)

// ✅ Good: new method with old behavior preserved
function getUser($id)  // unchanged
function getUserWithRelations(int $id)  // new
```

### No full rewrite of a file in one go

Progressive strategy:

1. **Wrapper**: create a new class that calls the old one
2. **Delegation**: route calls through the wrapper
3. **Reimplementation**: fill the new class with the modernized logic
4. **Switch-over**: point callers at the new class
5. **Removal**: delete the old class once all callers are migrated

### One step = one local commit; one step = one phase when bisectability matters

- No big "WIP" commit that breaks everything
- If a refactor requires 10 steps, that's 10 local commits, each passing the tests
- For a structural refactor, give **each step its own implementation phase** in `tasks.md`: the squashed history keeps one commit per step and stays bisectable if a regression is detected later
- Never group several refactor steps into one phase — the phase commit is the revert/bisect unit

## Database migrations

If the modification touches the DB schema:

### Every migration must have a reversible `down()`

```php
// Good
public function up(): void
{
    $this->addSql('ALTER TABLE user ADD COLUMN email VARCHAR(255) NOT NULL DEFAULT ""');
}

public function down(): void
{
    $this->addSql('ALTER TABLE user DROP COLUMN email');
}
```

### Adding vs Removing a column

- **Adding**: generally safe if nullable or with a default value
- **Removing**: do it in two steps
  1. Step 1: remove all usages in the code (deployment A)
  2. Step 2: drop the column in the DB (deployment B)

Never drop a column **in the same deployment** as the code that used it.

## Code removal

### Before removing a class, function, or constant

1. Search for all usages (`grep -r`, IDE find usages)
2. Check for usages in:
   - The source code
   - The tests
   - Configuration files
   - Templates / views
   - Cron jobs / scripts
   - Autoload files
3. If even a single usage exists → do not remove, mark `@deprecated` instead

### `@deprecated` before removal

```php
/**
 * @deprecated since 2.0, use UserService::find() instead.
 *             Will be removed in version 3.0.
 */
public function getUser($id) { ... }
```

## Progressive extraction strategy

To turn procedural code into OOP:

### Step 1 — Identify responsibilities

```php
// BEFORE: monolithic function
function processOrder($orderId) {
    // 1. Load the order
    // 2. Compute the total
    // 3. Apply promotions
    // 4. Send the confirmation email
    // 5. Log the operation
}
```

### Step 2 — Extract into classes by responsibility

```php
final class OrderLoader { ... }
final class OrderTotalCalculator { ... }
final class PromotionApplier { ... }
final class OrderConfirmationMailer { ... }
final class OrderLogger { ... }
```

### Step 3 — Orchestration wrapper

```php
final class OrderProcessor
{
    public function __construct(
        private readonly OrderLoader $loader,
        private readonly OrderTotalCalculator $calculator,
        // ...
    ) {}

    public function process(int $orderId): void
    {
        $order = $this->loader->load($orderId);
        $this->calculator->calculate($order);
        // ...
    }
}
```

### Step 4 — Replace the old call

```php
// Old code in index.php
// processOrder($orderId);

// New code
$processor = $container->get(OrderProcessor::class);
$processor->process($orderId);
```

### Step 5 — Remove the old function

Once all callers are migrated, remove `processOrder()`.

## Useful tools during the refactor

- **PHPStan baseline**: `vendor/bin/phpstan analyse --generate-baseline` to freeze existing errors and tackle only new ones
- **Rector**: automation of standard modernizations (PHP 7.4 → 8.x, etc.)
- **PHPUnit with coverage**: see what is tested before touching anything

## Documentation

Every structural refactor must produce:

1. A **SDD spec** (`/sdd-spec`) with non-regression acceptance criteria
2. A **plan** (`/sdd-plan`) with the progressive extraction strategy
3. Atomic **tasks** (`/sdd-tasks`) per step
4. If breaking change: a `breaking-changes.md` file in the feature folder

## Special case: global variables

If the legacy code relies on global variables (`$db`, `$config`, etc.), the strategy is:

1. Identify the value of the global at call time
2. Pass it as a parameter to the new class
3. Make the class the owner of that value (constructor injection)
4. Once the migration is done, remove the global

```php
// BEFORE
function getUser($id) {
    global $db;
    return $db->query("SELECT * FROM user WHERE id = $id")->fetch();
}

// STEP 1 — Wrapper that takes the PDO as a parameter
final class UserRepository
{
    public function __construct(private readonly \PDO $db) {}
    
    public function find(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM user WHERE id = ?');
        $stmt->execute([$id]);
        return $stmt->fetch() ?: null;
    }
}

// STEP 2 — Progressive switch-over of callers
global $db;
$repo = new UserRepository($db);
$user = $repo->find($id);

// STEP 3 — Once all callers are migrated, remove the `global`
```
