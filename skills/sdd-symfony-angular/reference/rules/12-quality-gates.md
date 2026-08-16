# Quality gates — Symfony + Angular

> **Layer 2 — Specific to the full-stack Symfony + Angular stack.**  
> Covers both sides. For pure backend details, see also `sdd-php-symfony`.

---

## Overview

| Layer | Tools | Target |
|---|---|---|
| Backend static | PHPStan, PHP-CS-Fixer, Rector | PHPStan level 8, PSR-12 |
| Frontend static | ESLint, TypeScript strict, Prettier | strict TS, ESLint Angular recommended |
| Backend tests | PHPUnit + coverage | 70-90% depending on layer |
| Frontend tests | Jest + coverage | 70-85% depending on layer |

---

## Symfony backend

### PHPStan

```bash
cd backend
composer require --dev phpstan/phpstan phpstan/phpstan-symfony phpstan/phpstan-doctrine
```

`backend/phpstan.neon`:

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

```bash
composer require --dev friendsofphp/php-cs-fixer
```

`.php-cs-fixer.dist.php` (see `sdd-php-symfony/12-quality-gates.md` for details).

### Rector

```bash
composer require --dev rector/rector
```

### Commands

```bash
cd backend
vendor/bin/phpstan analyse
vendor/bin/php-cs-fixer fix --dry-run --diff
vendor/bin/rector process --dry-run
```

---

## Angular frontend

### ESLint

The Angular CLI installs ESLint by default. Check `eslint.config.mjs` (Angular 18+) or `.eslintrc.json`:

Recommended configuration:

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

### TypeScript strict

`tsconfig.json` (excerpt):

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

### Prettier (optional but recommended)

```bash
npm install --save-dev prettier
```

`.prettierrc`:

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
cd frontend
npm run lint                          # ESLint
npx tsc --noEmit                       # type-check without build
npx prettier --check src/              # check formatting
npx prettier --write src/              # apply formatting
```

---

## Pre-commit hooks

`Husky` (Node) or plain bash hooks.

`.husky/pre-commit`:

```bash
#!/bin/bash
set -e

# Backend
if git diff --cached --name-only | grep -q '^backend/'; then
  echo "🔍 Backend quality..."
  cd backend
  vendor/bin/phpstan analyse --no-progress
  vendor/bin/php-cs-fixer fix --dry-run --diff
  cd ..
fi

# Frontend
if git diff --cached --name-only | grep -q '^frontend/'; then
  echo "🎨 Frontend quality..."
  cd frontend
  npm run lint
  npx tsc --noEmit
  cd ..
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
cd backend
vendor/bin/phpunit --coverage-cobertura=coverage.xml
diff-cover coverage.xml --compare-branch=origin/develop --fail-under=60   # Medium — 80 in Strict
```

`diff-cover` (Python, `pipx install diff-cover`). Aim for 90% on business
services as a review target.

### Frontend

```bash
cd frontend
npm test -- --coverage --watch=false
```

Suggested thresholds: 75% global, 85% on services.

`jest.config.js`:

```js
module.exports = {
  // ...
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 75,
      lines: 75,
      statements: 75,
    },
  },
};
```

---

## In the project's CI

These gates run in the project's **existing** pipeline, at its quality stage — the toolkit prescribes what must be green, never how the pipeline is wired. Backend: PHPStan, PHP-CS-Fixer (dry-run), PHPUnit unit then integration (database service + test-schema bootstrap `doctrine:database:create/schema:create --env=test`); frontend: ESLint, `tsc --noEmit`, production build, tests with coverage.

## Makefile to orchestrate everything

`Makefile` (project root):

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
