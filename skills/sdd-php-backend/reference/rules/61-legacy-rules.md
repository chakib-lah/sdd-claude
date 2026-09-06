# Legacy Rules — Coexistence of legacy and new code

> **Layer 2 — Brownfield-specific.**  
> Rules for making existing legacy code and new SDD-disciplined code live together.

---

## Guiding principle

> New code is **not required** to pull the legacy upward, but the legacy has **no right** to pull the new code downward.

In other words:
- Legacy code stays as-is unless modified as part of a feature
- New code always follows `10-code-conventions.md`
- The interface between the two is treated as an anti-corruption contract

## Legacy / new code boundary

### Physical organization

```
src/
├── Legacy/                     ← Isolated legacy code
│   ├── user_functions.php
│   ├── OldOrderManager.php
│   └── old_helpers.php
├── Service/                    ← New code only
├── Repository/                 ← New code only
├── Adapter/                    ← Anti-corruption layer
│   └── LegacyUserAdapter.php   ← Wrappers between legacy and new
└── Entity/                     ← New code only
```

### Anti-corruption layer (Adapter)

Every interaction between new code and legacy goes through a dedicated **Adapter**:

```php
// ✅ Good: adapter that isolates the legacy
namespace App\Adapter;

final class LegacyUserAdapter
{
    public function getUserData(int $userId): UserDataDTO
    {
        // Call to the legacy
        $rawData = get_user_legacy($userId);
        
        // Conversion to a modern, typed DTO
        return new UserDataDTO(
            id: (int) $rawData['id'],
            email: (string) $rawData['email'],
            createdAt: new \DateTimeImmutable($rawData['created']),
        );
    }
}

// ✅ The new service uses the adapter, never the legacy directly
final class UserService
{
    public function __construct(
        private readonly LegacyUserAdapter $legacyAdapter,
    ) {}

    public function process(int $userId): void
    {
        $userData = $this->legacyAdapter->getUserData($userId);
        // ...
    }
}
```

## Coexistence rules

### Rule 1 — Do not mix PSR-4 and manual `require` in the same file

```php
// ❌ Bad
<?php
declare(strict_types=1);
namespace App\Service;

require_once __DIR__ . '/../Legacy/old_helpers.php';  // ← forbidden

final class NewService { ... }
```

```php
// ✅ Good: go through a wrapper
<?php
declare(strict_types=1);
namespace App\Service;

final class NewService
{
    public function __construct(
        private readonly LegacyHelpersAdapter $legacyHelpers,  // ← wrapper that isolates the require
    ) {}
}
```

### Rule 2 — Do not mix typed validation and direct superglobal access

```php
// ❌ Bad
public function createUser(string $email): void
{
    $password = $_POST['password'];  // ← forbidden in new code
    // ...
}
```

```php
// ✅ Good: injection or typed parameter
public function createUser(string $email, string $password): void
{
    // ...
}

// The controller (if there is one) or the bootstrap handles the transition
$service->createUser(
    email: (string) ($_POST['email'] ?? ''),
    password: (string) ($_POST['password'] ?? ''),
);
```

### Rule 3 — Never extend a legacy class from a new class

```php
// ❌ Bad
final class NewUserManager extends OldUserManager { ... }
```

```php
// ✅ Good: composition via adapter
final class NewUserManager
{
    public function __construct(
        private readonly LegacyUserAdapter $legacyAdapter,
    ) {}
}
```

### Rule 4 — Legacy dependencies are tracked outside the source

Source comments are never a migration backlog: no mandatory marker (`// LEGACY:`, `// MIGRATION:`), no ticket id, no "to be replaced once migrated" promise in product source (see `.claude/rules/03-code-quality.md` § Source comments). Dependencies on legacy code and their migration priorities are tracked in the debt document below, the real issue tracker, and the SDD artifacts of the migration features.

A comment at a legacy call site remains legitimate when a **non-obvious legacy constraint** genuinely needs explaining for the code to stay understandable — concise English, current code/domain intent only:

```php
// Preserve the legacy data shape required by this integration.
$rawData = get_user_legacy($userId);
```

The comment explains WHY the current code behaves that way — never WHEN someone should migrate it.

### Rule 5 — Any modification of a legacy file goes through a SDD refactor

- No "quick" bugfix that worsens coupling
- If you modify a legacy file, it's an opportunity to extract it into new code (see `60-refactoring-guard.md`)
- At minimum, add a characterization test before the modification

## The `docs/legacy-debt.md` file

A **technical debt** file is maintained at the root of `docs/` (or another agreed location) to track:
- Legacy modules to migrate
- Effort estimates
- Priority
- Dependencies

Suggested format:

```markdown
# Legacy debt

## Modules to migrate

| Module | Location | Priority | Estimated effort | Blockers | Migration ticket |
|---|---|---|---|---|---|
| User management | src/Legacy/user_functions.php | High | 2 weeks | DB migration users → user | TICK-1200 |
| Order management | src/Legacy/OldOrderManager.php | Medium | 3 weeks | - | TICK-1300 |
| Global helpers | src/Legacy/old_helpers.php | Low | 1 week | Identify all callers | - |

## Adapters in place

| Adapter | Wraps | Status |
|---|---|---|
| LegacyUserAdapter | get_user_legacy() | ✅ in place |
| LegacyOrderAdapter | OldOrderManager | ⏳ partial |

## Remaining global variables

| Global | Location | Migration plan |
|---|---|---|
| `$GLOBALS['db']` | everywhere in Legacy/ | Inject PDO via constructor (TICK-1100) |
| `$_SESSION['user_id']` | Legacy/auth.php | SessionManager service (TICK-1110) |
```

## Progressive migration strategy

### The "Strangler Fig" approach

The Strangler Fig pattern consists of:
1. Identify a legacy module
2. Build a modern version alongside it
3. Progressively redirect callers to the modern version
4. Once 100% of callers are migrated, remove the legacy

```
Phase 1:            Phase 2:            Phase 3:
                                        
Caller 1 ─┐         Caller 1 ─┬───→ NEW   Caller 1 ─┐
Caller 2 ─┼→ LEGACY  Caller 2 ─┘             ↓       
Caller 3 ─┘         Caller 3 ──→ LEGACY    Caller 2 ─┼→ NEW
                                           Caller 3 ─┘
```

### Priority migration criteria

Migrate first the modules that:
1. **Have the most recurring bugs** (the legacy is probably the cause)
2. **Require frequent evolutions** (the legacy slows the team down)
3. **Pose a security risk** (missing validation, inline SQL, etc.)
4. **Sit on the critical path** (what users see the most)

## Anti-patterns

- ❌ "Big rewrite": rewriting everything at once → total failure in 90% of cases
- ❌ Refactoring without prior tests → invisible regressions introduced
- ❌ Mixing legacy / new code in the same file → increased debt
- ❌ Bug fix in the legacy without a non-regression test → the bug comes back
- ❌ Adapter that contains business logic → the adapter becomes a Frankenstein
- ❌ Renaming a legacy file "to make it clean" → breaks requires and autoloads

## Progress indicators

To track in `legacy-debt.md` or a dashboard:

- Number of files in `src/Legacy/` (must decrease)
- Number of referenced global variables (must decrease)
- Number of adapters in place (may grow then shrink)
- Test coverage on legacy modules (must increase)
- Number of new-code call sites that depend on legacy modules, as inventoried in the debt document (must decrease) — never measured by counting tracking comments in source
