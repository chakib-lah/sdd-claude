# Quality gates — Spring Boot + Angular

> **Layer 2 — Specific to the full-stack Spring Boot + Angular stack.**  
> Covers both sides. For pure backend details, see also `sdd-java-backend`.

---

## Overview

| Layer | Tools | Target |
|---|---|---|
| Backend static | Checkstyle / Spotless, Sonar | zero new violations |
| Frontend static | ESLint (`--max-warnings=0`), TypeScript strict | zero warnings |
| Backend tests | JUnit 5 + JaCoCo verification | 70-90% depending on layer |
| Frontend tests | Karma/Jasmine or Jest + coverage | 70-85% depending on layer |
| Build | `./gradlew check` + `ng build --configuration production` | both green |
| Contract | OpenAPI ⇄ TypeScript types in sync | no drift |

---

## Spring Boot backend

### Full gate

```bash
cd backend
./gradlew check          # compile + tests + checkstyle + coverage verification
```

`check` is the single backend gate: everything blocking must be wired into it
(`unitTest`, `integrationTest`, style, `jacocoTestCoverageVerification`).

### JaCoCo verification

```groovy
jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                counter = 'LINE'
                value = 'COVEREDRATIO'
                minimum = 0.60          // adapt per strictness level
            }
        }
    }
}

tasks.named('check') {
    dependsOn 'jacocoTestCoverageVerification'
}
```

With a split `unitTest` / `integrationTest` setup, wire the execution data of
**both** tasks into the report and the verification — otherwise JaCoCo only sees
the default `test` task and the numbers are wrong:

```groovy
tasks.named('jacocoTestReport') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
tasks.named('jacocoTestCoverageVerification') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
```

### SonarQube

```groovy
sonar {
    properties {
        property 'sonar.host.url', 'https://sonar.example.com'   // adapt to your instance
        property 'sonar.projectKey', 'my-project-backend'
        property 'sonar.coverage.jacoco.xmlReportPaths',
                 'build/reports/jacoco/test/jacocoTestReport.xml'
    }
}
```

Token from the `SONAR_TOKEN` environment variable — never committed. On brownfield
projects, configure the quality gate on **new code** only (Clean as You Code).

### gradle.lockfile gate

- `gradle.lockfile` is **committed** to the repository
- After **any** change to `build.gradle` (dependency, plugin, or `ext` version
  property), regenerate it:

```bash
cd backend
./gradlew dependencies --write-locks
```

- CI fails with `LockOutOfDateException` when the lockfile is stale — the fix is
  always to regenerate and commit, never to disable locking
- Never edit `gradle.lockfile` by hand

Maven note: versions are locked by the POM itself (plus the Spring Boot BOM) — the
equivalent gate is reviewing every `<properties>` version change in the MR.

### Commands

```bash
cd backend
./gradlew check                             # full gate
./gradlew checkstyleMain                    # style only
./gradlew jacocoTestCoverageVerification    # coverage threshold only
./gradlew sonar                             # Sonar analysis

# Maven equivalents
mvn verify
mvn checkstyle:check
mvn sonar:sonar
```

---

## Angular frontend

### ESLint — zero warnings

```bash
cd frontend
ng lint                                     # via angular-eslint
npx eslint . --max-warnings=0               # equivalent, blocking on warnings
```

Recommended rules (excerpt of `eslint.config.mjs`):

```js
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

### TypeScript strict + type-check gate

`tsconfig.json` (excerpt):

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true
  },
  "angularCompilerOptions": {
    "strictInjectionParameters": true,
    "strictTemplates": true
  }
}
```

```bash
cd frontend
npx tsc --noEmit          # type-check without build — must pass
```

### Production build gate

```bash
cd frontend
ng build --configuration production
```

The production build **must pass** — AOT template errors and budget violations only
surface here, not in `ng serve`.

### Bundle budgets

`angular.json` (excerpt):

```json
"budgets": [
  { "type": "initial", "maximumWarning": "500kB", "maximumError": "1MB" },
  { "type": "anyComponentStyle", "maximumWarning": "4kB", "maximumError": "8kB" }
]
```

A budget `maximumError` breach fails the build. Raising a budget requires an
explicit team decision documented in the MR — never a silent bump.

### Commands

```bash
cd frontend
ng lint                                     # ESLint
npx tsc --noEmit                            # type-check
ng test --watch=false --browsers=ChromeHeadless --code-coverage
ng build --configuration production         # build + budgets
```

---

## Contract gate — OpenAPI ⇄ frontend types

The OpenAPI contract exposed by springdoc and the frontend TypeScript types
(generated or hand-written) must be **in sync**:

- Backend: springdoc-openapi serves the contract (`/v3/api-docs`); export it as a
  committed artifact when the API changes
- Frontend: types are either generated from that contract (via
  `@openapitools/openapi-generator-cli`) or hand-written interfaces that mirror the
  backend records name-for-name

**Gate**: any MR that changes a `@RestController`, a Request/Response record, or a
frontend API interface must show the two sides updated together. Run the
`/api-contract` command (`.claude/commands/api-contract.md`) to check and re-sync;
the full workflow is described in the `api-contracts.md` rule.

```bash
# Typical drift check (generated types)
cd frontend
npx @openapitools/openapi-generator-cli generate -g typescript-angular \
  -i ../api-docs/openapi.json -o src/app/generated/api
test -z "$(git status --porcelain -- src/app/generated/api)"   # fails on drift, including untracked generated files
```

---

## Pre-commit hooks

`Husky` (Node) or plain bash hooks.

```bash
#!/bin/bash
# .husky/pre-commit
set -e

# Backend
if git diff --cached --name-only | grep -q '^backend/'; then
  echo "🔍 Backend quality..."
  (cd backend && ./gradlew spotlessCheck checkstyleMain unitTest --quiet)
fi

# Frontend
if git diff --cached --name-only | grep -q '^frontend/'; then
  echo "🎨 Frontend quality..."
  (cd frontend && npx eslint . --max-warnings=0 && npx tsc --noEmit)
fi

echo "✅ Quality gates OK"
```

⚠️ **Never `git commit --no-verify`**.

---

## Test coverage

### Backend

```bash
cd backend
./gradlew jacocoTestReport jacocoTestCoverageVerification
```

Suggested thresholds: 60% to start, 80% at maturity, 90% on business services.
Exclude trivial generated code (`**/dto/**` records, `**/config/**`, `*Application`).

### Frontend

```bash
cd frontend
ng test --watch=false --browsers=ChromeHeadless --code-coverage
```

`karma.conf.js` (or `coverageThreshold` in `jest.config.js`):

```js
coverageReporter: {
  check: {
    global: { statements: 75, branches: 70, functions: 75, lines: 75 },
  },
},
```

Suggested thresholds: 75% global, 85% on services.

---

## Typical CI

```yaml
stages:
  - quality
  - test
  - build

# === BACKEND ===
backend:quality:
  stage: quality
  image: gradle:9-jdk21
  script:
    - cd backend
    - ./gradlew checkstyleMain spotlessCheck --no-daemon

backend:tests:
  stage: test
  image: gradle:9-jdk21
  services:
    - postgres:16
  variables:
    SPRING_PROFILES_ACTIVE: ci
    POSTGRES_DB: app_test
    POSTGRES_USER: app
    POSTGRES_PASSWORD: app
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/app_test
    SPRING_DATASOURCE_USERNAME: app
    SPRING_DATASOURCE_PASSWORD: app
  script:
    - cd backend
    - ./gradlew check jacocoTestReport --no-daemon   # fails on LockOutOfDateException if lockfile is stale
  artifacts:
    reports:
      junit: backend/build/test-results/**/*.xml

# === FRONTEND ===
frontend:quality:
  stage: quality
  image: node:22
  script:
    - cd frontend && npm ci
    - npx eslint . --max-warnings=0
    - npx tsc --noEmit

frontend:tests:
  stage: test
  image: node:22
  script:
    - cd frontend && npm ci
    - npx ng test --watch=false --browsers=ChromeHeadless --code-coverage

frontend:build:
  stage: build
  image: node:22
  script:
    - cd frontend && npm ci
    - npx ng build --configuration production
```

Adapt images and services to the project (Testcontainers needs a Docker-capable
runner; Karma needs Chromium available in the image).

---

## Makefile to orchestrate everything

`Makefile` (project root):

```makefile
.PHONY: quality test check

quality:
	cd backend && ./gradlew checkstyleMain spotlessCheck
	cd frontend && npx eslint . --max-warnings=0 && npx tsc --noEmit

test:
	cd backend && ./gradlew unitTest integrationTest
	cd frontend && npx ng test --watch=false --browsers=ChromeHeadless

check: quality test
	cd frontend && npx ng build --configuration production
```

---

## Gate summary before merge

Before any MR is merged, all of the following must be green locally and in CI:

1. `./gradlew check` (backend: compile, tests, style, coverage verification)
2. `gradle.lockfile` up to date with `build.gradle`
3. `ng lint` / ESLint with zero warnings + `npx tsc --noEmit`
4. Frontend tests green + `ng build --configuration production` passes budgets
5. OpenAPI contract and frontend types in sync (`/api-contract`)
6. Sonar quality gate passed on new code (if Sonar is configured)

---

## Anti-patterns

- ❌ `--no-verify` on git commit
- ❌ Disabling an ESLint or Checkstyle rule without documenting why (ticket reference)
- ❌ `any` in TypeScript code, bare `@SuppressWarnings` in Java
- ❌ Raising a bundle budget silently to make the build pass
- ❌ Regenerating the lockfile "to fix CI" without understanding which dependency moved
- ❌ Updating a backend record without updating the frontend interface (or vice versa)
- ❌ Disabled tests (`xit`, `@Disabled`) without a re-enable ticket
- ❌ CI pipeline that passes with ignored warnings
