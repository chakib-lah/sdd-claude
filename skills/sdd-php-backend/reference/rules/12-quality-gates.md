# Quality gates — PHP

> **Layer 2 — Specific to the PHP stack (no framework).**  
> For legacy projects, the approach is progressive: start soft, tighten over time.

---

## Overview

Three levels of quality gates, depending on project maturity:

| Level | Target | Tools |
|---|---|---|
| **Soft** | Legacy projects starting their migration | PHPStan level 0-3, syntax only |
| **Medium** | Projects being modernized | PHPStan 4-6, light PHP-CS-Fixer |
| **Strict** | Recent, demanding code | PHPStan 7-9, full CS-fixer, Rector |

To choose at SDD installation time based on the project context.

## Recommended tools

### Static analysis: PHPStan

Installation:

```bash
composer require --dev phpstan/phpstan
```

`phpstan.neon` configuration:

```neon
parameters:
    level: 5
    paths:
        - src/
    excludePaths:
        - src/Legacy/
    ignoreErrors:
        # List of temporarily tolerated warnings
```

### Formatting: PHP-CS-Fixer

Installation:

```bash
composer require --dev friendsofphp/php-cs-fixer
```

`.php-cs-fixer.php` configuration:

```php
<?php
return (new PhpCsFixer\Config())
    ->setRules([
        '@PSR12' => true,
        'declare_strict_types' => true,
        'array_syntax' => ['syntax' => 'short'],
        'ordered_imports' => true,
        'no_unused_imports' => true,
    ])
    ->setFinder(
        PhpCsFixer\Finder::create()
            ->in(__DIR__ . '/src')
            ->exclude('Legacy')
    );
```

### Modernization: Rector (optional, recommended for migrations)

Installation:

```bash
composer require --dev rector/rector
```

`rector.php` configuration:

```php
<?php
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\LevelSetList;
use Rector\Set\ValueObject\SetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([__DIR__ . '/src']);
    $rectorConfig->sets([
        LevelSetList::UP_TO_PHP_81,
        SetList::CODE_QUALITY,
        SetList::DEAD_CODE,
    ]);
    $rectorConfig->skip([
        __DIR__ . '/src/Legacy',
    ]);
};
```

## PHPStan levels in detail

| Level | What gets detected |
|---|---|
| 0 | Basic syntax, nonexistent classes |
| 1 | Possibly undefined variables |
| 2 | Methods/properties on unknown types |
| 3 | Return types, non-public methods |
| 4 | Basic dead code |
| 5 | Parameter types at call sites |
| 6 | Missing types |
| 7 | Partially correct union types |
| 8 | Unhandled `null` types |
| 9 | Strict — `mixed` types forbidden |

**Recommendation by context**:
- Legacy project starting SDD → level 2-3
- Project being modernized → level 5-6
- Recent new code → level 8

## Execution commands

To adapt to the project. By default:

```bash
# Static analysis
vendor/bin/phpstan analyse

# Formatting (check without fixing)
vendor/bin/php-cs-fixer fix --dry-run --diff

# Formatting (fix)
vendor/bin/php-cs-fixer fix

# Modernization (check without fixing)
vendor/bin/rector process --dry-run

# Modernization (fix)
vendor/bin/rector process
```

If a `Makefile` is present, create a `quality` target:

```makefile
quality:
	vendor/bin/phpstan analyse
	vendor/bin/php-cs-fixer fix --dry-run --diff
	vendor/bin/rector process --dry-run
```

## Pre-commit hooks

Recommended: use `pre-commit` (Python) or `husky` (Node) or a home-grown bash script.

Example `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "Running PHPStan..."
vendor/bin/phpstan analyse --no-progress || exit 1

echo "Running PHP-CS-Fixer (dry-run)..."
vendor/bin/php-cs-fixer fix --dry-run --diff || exit 1

echo "Quality gates: OK ✅"
```

⚠️ **Never `git commit --no-verify`**: if a hook blocks, fix the problem.

## Test coverage as a gate

Target: minimum coverage on **new code** (not on the legacy).

```bash
vendor/bin/phpunit --coverage-text --coverage-clover=coverage.xml
```

Suggested threshold (to tighten progressively):
- Start: no threshold
- 6 months: 50% on new files
- 1 year: 70% on new files
- 2 years: 85% overall

## CI/CD

Example steps for GitLab CI / GitHub Actions:

```yaml
quality:
  stage: quality
  script:
    - composer install --no-progress
    - vendor/bin/phpstan analyse
    - vendor/bin/php-cs-fixer fix --dry-run --diff
    - vendor/bin/phpunit --coverage-text
```

## How to tighten progressively

1. **Month 1**: install PHPStan level 0-2, fix what comes up
2. **Month 2**: move to level 3-4, fix the new warnings
3. **Month 3**: add PHP-CS-Fixer in dry-run on new files
4. **Month 6**: PHPStan level 5-6, CS-fixer in blocking mode
5. **Year 1**: Rector, level 7-8, 50% coverage
6. **Year 2**: level 9, legacy code migrated or refactored

## Explicit exceptions

If a legacy file cannot pass the target level:

```php
// at the top of the file
// @phpstan-ignore-file
```

Or in `phpstan.neon`:

```neon
parameters:
    ignoreErrors:
        -
            message: '#Property .* has unknown class .* as its type#'
            path: src/Legacy/LegacyService.php
```

**Golden rule**: every ignore must be documented with a reason and an intent to resolve it.
