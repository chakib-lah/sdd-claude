# Quality gates — PHP / Symfony

> **Layer 2 — Specific to the PHP/Symfony stack.**

---

## Required capabilities vs discovered parameters

This rule names the quality capabilities **required** by the PHP/Symfony skill. Their concrete parameters are **project facts** — discovered from the repository, never edited into this Layer-2 rule:

| Capability | Status | Current parameters (discovered) |
|---|---|---|
| Automated tests (PHPUnit) | **Required** | suites, directories, execution wrapper (see `11-tests-strategy.md`) |
| PHPStan static analysis | **Required** | installed version, config path, configured level |
| Rector automated refactoring | **Required** | installed version, `rector.php` rule sets and skips |
| PHP-CS-Fixer formatting | **Required** | config file, execution wrapper |

**Discovery is not optionality.** A missing required capability is a **PROJECT_TOOLING_GAP** (see the three states below) — never evidence that the requirement does not apply. The project's *current configured state* (e.g. its PHPStan level) is what gets enforced today; the *capability itself* is not negotiable per project. Layer 3 may specialize parameters and document rollout context, but it cannot negate a required capability.

### The three states of a required capability

- **Present and configured** — discover the configuration, use the project's wrapper, enforce it with **no regression**.
- **Present but below the project's stated target** (e.g. PHPStan level lower than the target recorded in `.claude/rules/project-quality.md`) — report the concrete gap; do not silently perform a broad migration inside an unrelated feature; tightening is a dedicated quality change.
- **Absent** — report **PROJECT_TOOLING_GAP**. The capability remains required; installing or configuring it is a dedicated tooling change, never a silent side effect of an unrelated feature. Absence is never an accepted project convention.

There is no fourth state: "absent, therefore not required" does not exist.

## Strictness profiles

Vocabulary for a project's quality maturity. On an existing project, the **actual** PHPStan level and coverage gate are discovered facts (PHPStan config, project CI); the target profile, if the team has chosen one, lives in `.claude/rules/project-quality.md` (Layer 3).

| Level | Profile | PHPStan | Coverage (diff) |
|---|---|---|---|
| **Soft** | Recent project just starting | level 5 | informative (report only) |
| **Medium** | Project being stabilized | level 7 | ≥ 60% on new/changed code |
| **Strict** | Mature, demanding code | level 8-9 | ≥ 80% on new/changed code |

**Greenfield default**: Strict, PHPStan level 8 (balance between robustness and pragmatism).

## Required tools

### PHPStan

**Required.** Discover the existing configuration first (`phpstan.neon` or `phpstan.dist.neon`) and the **configured level**, then enforce that level: no new errors. Never silently lower the configured level; never silently raise the whole project's level during an unrelated feature — raising it is a dedicated quality evolution. If PHPStan is absent: PROJECT_TOOLING_GAP.

Greenfield installation:

```bash
composer require --dev phpstan/phpstan phpstan/phpstan-symfony phpstan/phpstan-doctrine
```

Greenfield `phpstan.neon` starting point (an existing project's config — level, paths, excludes — is authoritative):

```neon
includes:
    - vendor/phpstan/phpstan-symfony/extension.neon
    - vendor/phpstan/phpstan-doctrine/extension.neon

parameters:
    level: 8
    paths:
        - src/
        - tests/
    excludePaths:
        - src/Legacy/
        - src/Migrations/
    symfony:
        containerXmlPath: var/cache/dev/App_KernelDevDebugContainer.xml
    doctrine:
        objectManagerLoader: tests/object-manager.php
```

### PHP-CS-Fixer

**Required** — deterministic formatting is part of the PHP/Symfony quality baseline. Discover the project's configuration (`.php-cs-fixer.dist.php` / `.php-cs-fixer.php`) and its execution wrapper, and enforce it on changed code. If absent: PROJECT_TOOLING_GAP — never treat the absence of a formatter as an accepted final state, and never silently install one during an unrelated feature.

Greenfield installation:

```bash
composer require --dev friendsofphp/php-cs-fixer
```

Greenfield `.php-cs-fixer.dist.php` starting point:

```php
<?php

return (new PhpCsFixer\Config())
    ->setRules([
        '@PSR12' => true,
        '@PHP82Migration' => true,
        '@Symfony' => true,
        'declare_strict_types' => true,
        'array_syntax' => ['syntax' => 'short'],
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'no_unused_imports' => true,
        'single_quote' => true,
        'trailing_comma_in_multiline' => true,
        'phpdoc_align' => false,
    ])
    ->setRiskyAllowed(true)
    ->setFinder(
        PhpCsFixer\Finder::create()
            ->in(__DIR__ . '/src')
            ->in(__DIR__ . '/tests')
            ->exclude('Legacy')
            ->exclude('Migrations')
    );
```

### Rector

**Required** — automated, safe refactoring support is part of the skill's tooling baseline. Discover the existing `rector.php` (rule sets, paths, skips) and run it only through the project's configured, scoped workflow — never as a broad unrelated transformation during a feature. If absent: PROJECT_TOOLING_GAP.

Greenfield installation:

```bash
composer require --dev rector/rector
```

Greenfield `rector.php` starting point (set lists follow the **discovered** PHP/Symfony/Doctrine versions):

```php
<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\LevelSetList;
use Rector\Set\ValueObject\SetList;
use Rector\Symfony\Set\SymfonySetList;
use Rector\Doctrine\Set\DoctrineSetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([
        __DIR__ . '/src',
    ]);

    $rectorConfig->sets([
        LevelSetList::UP_TO_PHP_82,
        SetList::CODE_QUALITY,
        SetList::DEAD_CODE,
        SetList::TYPE_DECLARATION,
        SymfonySetList::SYMFONY_64,
        DoctrineSetList::DOCTRINE_ORM_29,
    ]);

    $rectorConfig->skip([
        __DIR__ . '/src/Legacy',
        __DIR__ . '/src/Migrations',
    ]);
};
```

## Execution commands

Use the project's established wrapper (Makefile, Composer scripts, Docker) when one exists — discover it, don't hard-code host binaries. Direct-host examples:

```bash
# Static analysis
vendor/bin/phpstan analyse

# Formatting (check)
vendor/bin/php-cs-fixer fix --dry-run --diff

# Formatting (fix)
vendor/bin/php-cs-fixer fix

# Modernization (check)
vendor/bin/rector process --dry-run

# Modernization (fix)
vendor/bin/rector process

# Grouped target if the project's Makefile defines one
make quality
```

**Greenfield** recommended `Makefile` `quality` target:

```makefile
quality: quality-phpstan quality-cs quality-rector

quality-phpstan:
	vendor/bin/phpstan analyse --no-progress

quality-cs:
	vendor/bin/php-cs-fixer fix --dry-run --diff

quality-rector:
	vendor/bin/rector process --dry-run
```

## Pre-commit hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "🔍 PHPStan..."
vendor/bin/phpstan analyse --no-progress

echo "🎨 PHP-CS-Fixer..."
vendor/bin/php-cs-fixer fix --dry-run --diff

echo "🚀 Rector..."
vendor/bin/rector process --dry-run

echo "✅ Quality gates OK"
```

⚠️ **Never `git commit --no-verify`**.

## Test coverage

Target: progressive thresholds based on maturity.

```xml
<!-- phpunit.dist.xml -->
<coverage>
    <include>
        <directory suffix=".php">src</directory>
    </include>
    <exclude>
        <directory>src/Legacy</directory>
        <directory>src/Migrations</directory>
        <directory>src/Kernel.php</directory>
    </exclude>
</coverage>
```

The gate is wired to the strictness levels above and measured on the **diff**
(new/changed code) — a global threshold on a legacy codebase is unenforceable,
which is why this stayed prose for so long. Executable gate, exits non-zero
below the threshold:

```bash
vendor/bin/phpunit --coverage-cobertura=coverage.xml
diff-cover coverage.xml --compare-branch=origin/<integration-branch> --fail-under=60   # Medium — 80 in Strict
```

The integration branch is policy-resolved (`01-git-conventions.md` § Effective Git policy resolution), never hard-coded here.

`diff-cover` (Python, `pipx install diff-cover`) is the diff-coverage arbiter;
at the Soft level run it without `--fail-under` (informative report only).
Aim also for 90% on business services as they stabilize — as a review target,
not a gate.

## In the project's CI

These checks belong in the project's **existing** pipeline, at its quality stage — the toolkit prescribes what must be green, never how the pipeline is wired. Run the same tools as locally: PHPStan, PHP-CS-Fixer (dry-run), Rector (dry-run) where the project wires it, then the PHPUnit suites — the integration-level job needs a database and the project's own test-schema bootstrap (its dedicated target/script when one exists). CI topology is a **discovered fact**: read the project's actual pipeline to know which jobs exist and which ones block — never invent a job name or assert that a check is blocking without the pipeline proving it.

## Ignoring errors

If a PHPStan error cannot be resolved immediately:

```neon
parameters:
    ignoreErrors:
        -
            message: '#Property .* has unknown class .* as its type#'
            path: src/Service/SomeLegacyAdapter.php
            count: 1
```

Always **document the reason** and the **intent to resolve** (Jira ticket).

## Baseline mode for brownfield projects

```bash
vendor/bin/phpstan analyse --generate-baseline
```

Generates `phpstan-baseline.neon`, which freezes all existing errors. To include in `phpstan.neon`:

```neon
includes:
    - phpstan-baseline.neon
```

The goal is then to **shrink the baseline** progressively, not to ignore it.
