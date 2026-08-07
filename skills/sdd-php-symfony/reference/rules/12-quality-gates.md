# Quality gates — PHP / Symfony

> **Layer 2 — Specific to the PHP/Symfony stack.**

---

## Strictness levels

Three levels to choose from at SDD installation time:

| Level | Profile | PHPStan |
|---|---|---|
| **Soft** | Recent project just starting | level 5 |
| **Medium** | Project being stabilized | level 7 |
| **Strict** | Mature, demanding code | level 8-9 |

**Default recommendation for your projects**: level 8 (balance between robustness and pragmatism).

## Mandatory tools

### PHPStan

Installation:

```bash
composer require --dev phpstan/phpstan phpstan/phpstan-symfony phpstan/phpstan-doctrine
```

`phpstan.neon` configuration:

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

Installation:

```bash
composer require --dev friendsofphp/php-cs-fixer
```

`.php-cs-fixer.dist.php` configuration:

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

### Rector (recommended)

Installation:

```bash
composer require --dev rector/rector
```

`rector.php` configuration:

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

# Recommended grouped target in the Makefile
make quality
```

Recommended `Makefile` `quality` target:

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

Suggested thresholds:
- Start: 50% overall
- 6 months: 70% overall, 90% on business services
- 1 year: 80% overall

Check in CI:

```bash
vendor/bin/phpunit --coverage-text --coverage-clover=coverage.xml
```

## Typical GitLab CI

```yaml
stages:
  - quality
  - test

phpstan:
  stage: quality
  script:
    - composer install --no-progress --no-interaction
    - vendor/bin/phpstan analyse --no-progress

cs-fixer:
  stage: quality
  script:
    - composer install --no-progress --no-interaction
    - vendor/bin/php-cs-fixer fix --dry-run --diff

phpunit-unit:
  stage: test
  script:
    - composer install --no-progress --no-interaction
    - vendor/bin/phpunit --testsuite=Unit

phpunit-integration:
  stage: test
  services:
    - postgres:15
  script:
    - composer install --no-progress --no-interaction
    - php bin/console doctrine:database:create --env=test --if-not-exists
    - php bin/console doctrine:schema:create --env=test
    - vendor/bin/phpunit --testsuite=Integration --testsuite=Functional
```

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
