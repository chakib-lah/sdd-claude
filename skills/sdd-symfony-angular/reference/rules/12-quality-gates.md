# Quality gates — Symfony + Angular

> **Layer 2 — Specific to the full-stack Symfony + Angular stack.**  
> Covers both sides.

---

## Required capabilities vs discovered parameters

This rule names the quality capabilities **required** by the full-stack skill. Their concrete parameters are **project facts** — discovered from the repository, never edited into this Layer-2 rule. Both roots are discovered too (never assumed to be `backend/`/`frontend/`); `<backend-root>`/`<frontend-root>` below stand for the discovered directories.

| Side | Capability | Status | Current parameters (discovered) |
|---|---|---|---|
| Backend | Automated tests (PHPUnit) | **Required** | suites, directories, wrapper (see `11-tests-strategy.md`) |
| Backend | PHPStan static analysis | **Required** | installed version, config path, configured level |
| Backend | Rector automated refactoring | **Required** | installed version, `rector.php` rule sets and skips |
| Backend | PHP-CS-Fixer formatting | **Required** | config file, execution wrapper |
| Frontend | Automated Angular tests | **Required** — Vitest is the modern target | actual runner, `angular.json` test builder, scripts |
| Frontend | Linting | **Required** — ESLint + angular-eslint is the modern target | actual lint setup (ESLint / TSLint / absent) |
| Frontend | Strict typing | **Required target** — TS `strict` + `strictTemplates` | current `tsconfig*.json` configuration |
| Frontend | Deterministic formatting | **Required** | configured formatter (Prettier or other) |
| Frontend | Production build / type check | **Required** | project build scripts |

**Discovery is not optionality.** Two gap classes cover every deviation:

- **PROJECT_TOOLING_GAP** — a required capability is **absent** (no PHPStan, no formatter, no test runner…). The capability remains required; installing/configuring it is a dedicated tooling change, never a silent side effect of an unrelated feature. Absence is never an accepted project convention.
- **PROJECT_MIGRATION_GAP** — the capability is present but in a **legacy or below-target state** (Karma/Jasmine instead of Vitest, TSLint instead of ESLint, strict mode disabled, PHPStan below the project's stated target…). The current configuration stays operational for feature work; the gap is reported; the migration is a dedicated task, never hidden inside a feature.

Layer 3 may specialize parameters and document rollout/ratchet policies; it cannot negate a required capability. There is no state "absent, therefore not required".

---

## Symfony backend — required tools

The backend keeps the same quality floor as the pure PHP/Symfony skill: **PHPUnit, PHPStan, Rector and PHP-CS-Fixer are required capabilities**, with parameters discovered under the discovered backend root.

### PHPStan

**Required.** Discover the existing configuration (`phpstan.neon`/`phpstan.dist.neon`) and the **configured level**, then enforce that level: no new errors. Never silently lower the configured level; never silently raise the whole project's level during an unrelated feature — tightening is a dedicated quality evolution. Absent: PROJECT_TOOLING_GAP.

Greenfield installation:

```bash
cd <backend-root>
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
    symfony:
        containerXmlPath: var/cache/dev/App_KernelDevDebugContainer.xml
    doctrine:
        objectManagerLoader: tests/object-manager.php
```

### PHP-CS-Fixer

**Required** — deterministic backend formatting is part of the quality baseline. Discover the project's configuration (`.php-cs-fixer.dist.php` / `.php-cs-fixer.php`) and its execution wrapper, and enforce it on changed code. Absent: PROJECT_TOOLING_GAP — never treat the absence of a formatter as an accepted final state, and never silently install one during an unrelated feature.

Greenfield installation:

```bash
composer require --dev friendsofphp/php-cs-fixer
```

### Rector

**Required** — automated, safe refactoring support is part of the tooling baseline. Discover the existing `rector.php` (rule sets, paths, skips) and run it only through the project's configured, scoped workflow — never as a broad unrelated transformation during a feature. Absent: PROJECT_TOOLING_GAP.

Greenfield installation:

```bash
composer require --dev rector/rector
```

### Commands

```bash
# Direct-host examples — use the project's established wrapper (Make/Docker/Composer) when one exists
cd <backend-root>
vendor/bin/phpstan analyse
vendor/bin/php-cs-fixer fix --dry-run --diff
vendor/bin/rector process --dry-run
```

---

## Angular frontend

### Lint — ESLint + angular-eslint (required target)

Angular linting quality is **required**, and the modern target is **ESLint + angular-eslint**. The Angular CLI does **not** install ESLint automatically — the actual lint setup is a project fact: discover `eslint.config.*` / `.eslintrc*`, the `lint` target in `angular.json`, the package dependencies and the project scripts. A TSLint-only project is a **PROJECT_MIGRATION_GAP**: keep the configured linter operational for feature work, report the gap, and migrate the lint system only in a dedicated task. No linting at all: PROJECT_TOOLING_GAP.

Greenfield `eslint.config.mjs` starting point (the `app` selector prefix below is the greenfield example — discover the project's real prefix from `angular.json`):

```js
// eslint.config.mjs (excerpt)
export default tseslint.config(
  {
    files: ['**/*.ts'],
    extends: [
      eslint.configs.recommended,
      ...tseslint.configs.recommendedTypeChecked,
      ...angular.configs.tsRecommended,
    ],
    processor: angular.processInlineTemplates,
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': 'error',
      '@typescript-eslint/explicit-function-return-type': ['warn', { allowExpressions: true }],
      '@angular-eslint/component-selector': [
        'error',
        { type: 'element', prefix: 'app', style: 'kebab-case' },
      ],
      '@angular-eslint/directive-selector': [
        'error',
        { type: 'attribute', prefix: 'app', style: 'camelCase' },
      ],
    },
  },
  {
    files: ['**/*.html'],
    extends: [
      ...angular.configs.templateRecommended,
      ...angular.configs.templateAccessibility,
    ],
  },
);
```

### TypeScript strict + strictTemplates (required target)

The quality target is TypeScript `strict` plus Angular `strictTemplates`. The current configuration is discovered from `tsconfig*.json`. If strict mode is currently disabled, that is a **PROJECT_MIGRATION_GAP**: preserve the current configuration, never toggle strict project-wide during an unrelated feature, report the gap — and new code still uses explicit safe typing and introduces no new `any` debt. Layer 3 (`.claude/rules/project-quality.md`) may document a rollout/ratchet policy; it may not declare strict typing unnecessary.

Greenfield `tsconfig.json` target (excerpt):

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  },
  "angularCompilerOptions": {
    "enableI18nLegacyMessageIdFormat": false,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}
```

### Deterministic formatting (required)

A deterministic frontend formatter is **required as a capability**. Discover the configured formatter first (Prettier config, ESLint-driven formatting, or another established tool) — never assume Prettier is already in use. Absent: PROJECT_TOOLING_GAP — no silent installation and no formatter-wide churn during an unrelated feature. **Prettier is the greenfield recommendation**:

```bash
npm install --save-dev prettier   # greenfield setup
```

Greenfield `.prettierrc`:

```json
{
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2,
  "semi": true
}
```

### Commands

```bash
# Always via the project's configured scripts/targets — direct examples shown
cd <frontend-root>
npm run lint                          # the project's lint target
npx tsc --noEmit                       # type-check without build
npx prettier --check src/              # if Prettier is the configured formatter
```

---

## Pre-commit hooks

`Husky` (Node) or plain bash hooks.

`.husky/pre-commit` (substitute the discovered roots and the project's own wrappers). `<repo-root>` is the repository root resolved **once** (e.g. `git rev-parse --show-toplevel` on a Git checkout — an implementation example, not a universal requirement); `<backend-root>`/`<frontend-root>` are repository-root-relative and may be nested at any depth (`apps/backend`, `clients/web/angular`…). Run project-local commands in a subshell — never rely on `cd ..` to recover the repository root:

```bash
#!/bin/bash
set -e

# Backend
if git diff --cached --name-only | grep -q '^<backend-root>/'; then
  echo "🔍 Backend quality..."
  ( cd "<repo-root>/<backend-root>" &&
    vendor/bin/phpstan analyse --no-progress &&
    vendor/bin/php-cs-fixer fix --dry-run --diff )
fi

# Frontend
if git diff --cached --name-only | grep -q '^<frontend-root>/'; then
  echo "🎨 Frontend quality..."
  ( cd "<repo-root>/<frontend-root>" &&
    npm run lint &&
    npx tsc --noEmit )
fi

echo "✅ Quality gates OK"
```

⚠️ **Never `git commit --no-verify`**.

---

## Test coverage

### Backend

Executable gate, measured on the **diff** (new/changed code — a global
threshold on legacy is unenforceable), exits non-zero below the threshold:

```bash
cd <backend-root>
vendor/bin/phpunit --coverage-cobertura=coverage.xml
diff-cover coverage.xml --compare-branch=origin/<integration-branch> --fail-under=60   # Medium — 80 in Strict
```

`diff-cover` (Python, `pipx install diff-cover`). The integration branch is policy-resolved (`01-git-conventions.md` § Effective Git policy resolution), never hard-coded here. Aim for 90% on business services as a review target.

### Frontend

Run coverage through the project's configured runner and scripts:

```bash
cd <frontend-root>
npm test -- --coverage
```

The enforced thresholds are the project's **configured** ones — discover them from the runner's coverage configuration (Vitest, Jest or Karma) and do not regress coverage on changed code. Greenfield recommendation: 75% global, 85% on services.

---

## In the project's CI

These gates run in the project's **existing** pipeline, at its quality stage — the toolkit prescribes WHAT must be green, never HOW the pipeline is wired. Backend: PHPStan, PHP-CS-Fixer (dry-run), Rector (dry-run) where the project wires it, PHPUnit unit then integration (database service + the project's own test-schema bootstrap); frontend: lint, `tsc --noEmit`, production build, tests with coverage. CI topology is a **discovered fact**: read the project's actual pipeline to know which jobs exist and which ones block — never invent a job name or assert that a check is blocking without the pipeline proving it.

## Makefile to orchestrate everything (greenfield example)

`Makefile` (project root — a project that already has its own targets keeps them; substitute the discovered roots):

```makefile
.PHONY: quality test test-backend test-frontend e2e

quality: quality-backend quality-frontend

quality-backend:
	cd backend && vendor/bin/phpstan analyse --no-progress
	cd backend && vendor/bin/php-cs-fixer fix --dry-run --diff

quality-frontend:
	cd frontend && npm run lint
	cd frontend && npx tsc --noEmit

test: test-backend test-frontend

test-backend:
	cd backend && vendor/bin/phpunit

test-frontend:
	cd frontend && npm test -- --watch=false

e2e:
	cd frontend && npx cypress run
```

---

## Anti-patterns

- ❌ `--no-verify` on git commit
- ❌ Disabling an ESLint rule without documenting why
- ❌ PHPStan baseline that keeps growing without a reduction plan
- ❌ `any` in TypeScript code
- ❌ Coverage that does not apply to new files
- ❌ Disabled tests (`xit`, `xdescribe`) without a re-enable ticket
- ❌ CI pipeline that passes with ignored warnings
