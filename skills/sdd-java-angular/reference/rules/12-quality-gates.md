# Quality gates — Spring Boot + Angular

> **Layer 2 — Specific to the full-stack Spring Boot + Angular stack.**  
> Covers both sides.

---

## Required capabilities vs discovered parameters

This rule names the quality capabilities **required** by the full-stack skill. Their concrete parameters are **project facts** — discovered from the repository, never edited into this Layer-2 rule. Both roots are discovered too (never assumed to be `backend/`/`frontend/`; the backend root — and the Gradle/Maven wrapper — may live at the repository root); `<backend-root>`/`<frontend-root>` below stand for the discovered directories.

| Side | Capability | Status | Current parameters (discovered) |
|---|---|---|---|
| Backend | Automated tests (JUnit 5) | **Required** | build tool, wrapper location, actual tasks/goals, suite convention (see `11-tests-strategy.md`) |
| Backend | Static/style quality | **Required** | configured implementation: Checkstyle, Spotless, Sonar rules, Error Prone, PMD, other equivalent |
| Backend | Coverage / quality evidence | **Required** | configured tool (JaCoCo is the common example), thresholds, report wiring |
| Backend | Deterministic formatting | **Required** | configured formatter (Spotless, enforced IDE/editorconfig setup, other) |
| Backend | Build verification | **Required** | Gradle `check` / Maven `verify` via the project wrapper |
| Backend | Dependency quality | **Required** | Gradle dependency locking **where enabled**, BOM discipline, security audit tooling |
| Frontend | Automated Angular tests | **Required** — Vitest is the modern target | actual runner (Vitest / Karma+Jasmine / Jest), `angular.json` test builder, scripts |
| Frontend | Linting | **Required** — ESLint + angular-eslint is the modern target | actual lint setup and its enforcement state |
| Frontend | Strict typing | **Required target** — TS `strict` + `strictTemplates` | current `tsconfig*.json` configuration |
| Frontend | Deterministic formatting | **Required** | configured formatter (Prettier or other) |
| Frontend | Production build / type check | **Required** | project build scripts |
| Full-stack | API contract sync | **Required** | contract source mode and generator (see `api-contracts.md`) |

**Discovery is not optionality.** Two gap classes cover every deviation:

- **PROJECT_TOOLING_GAP** — a required capability is **absent** (no static analysis at all, no formatter, no test runner…). The capability remains required; installing/configuring it is a dedicated tooling change, never a silent side effect of an unrelated feature. Absence is never an accepted project convention.
- **PROJECT_MIGRATION_GAP** — the capability is present but in a **legacy or below-target state** (Karma/Jasmine instead of Vitest, strict mode disabled, a lint setup that is configured but non-blocking or broken…). The current configuration stays operational for feature work; the gap is reported; the migration is a dedicated task, never hidden inside a feature. A configured but non-blocking/broken lint or quality setup is project state/debt — never silently rewrite it during unrelated work.

Layer 3 (`.claude/rules/project-quality.md`) may specialize parameters and document rollout/ratchet policies; it cannot negate a required capability. There is no state "absent, therefore not required".

---

## Spring Boot backend

### Aggregate gate

The single backend gate is the build tool's verification lifecycle, run through the **project wrapper at its discovered location** (which may be the repository root):

```bash
cd <repo-root>/<backend-root>
./gradlew check          # Gradle — or: mvn verify
```

Everything blocking must be wired into it: the project's discovered test tasks/goals, its configured style/static-analysis checks, its coverage verification. Which tasks exist is a **project fact** — list them (`./gradlew tasks`, or the POM's plugins) before invoking anything; never invoke a task (`spotlessCheck`, `checkstyleMain`, a custom test split…) that the build does not define.

### Static analysis and style — discovered implementation

Static/style quality is **required as a capability**; the implementation is discovered. Real projects satisfy it differently: Checkstyle, Spotless, Sonar rules on new code, Error Prone, PMD, or another configured equivalent. Run **only the project's configured checks** through its wrapper. No configured static/style check at all: **PROJECT_TOOLING_GAP** — report it; setting one up is a dedicated tooling task (greenfield defaults: Spotless for formatting, Checkstyle for style), never a silent install during a feature.

### Coverage — JaCoCo (common discovered example)

Coverage evidence is required; JaCoCo is the common Gradle/Maven implementation — discover its configuration and thresholds. Greenfield verification example:

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

With a split unit/integration setup, wire the execution data of **both** test tasks into the report and the verification — otherwise JaCoCo only sees the default `test` task and the numbers are wrong:

```groovy
tasks.named('jacocoTestReport') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
tasks.named('jacocoTestCoverageVerification') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
```

The enforced thresholds are the project's **configured** ones; never regress coverage on changed code. Greenfield suggestion: 60% to start, 80% at maturity, 90% on business services. Exclude trivial generated code (`**/dto/**` records, `**/config/**`, `*Application`).

### SonarQube (discovered example)

Where the project wires Sonar, it can carry the static-analysis and coverage-evidence capabilities:

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

Token from the `SONAR_TOKEN` environment variable — never committed. On brownfield projects, configure the quality gate on **new code** only (Clean as You Code).

### Dependency locking gate — where enabled

Gradle dependency locking is the **greenfield recommendation**, and whether it is enabled is a **project fact** (`dependencyLocking` in the build, `gradle.lockfile` present) — not every valid Gradle project uses it. **When locking is enabled**:

- `gradle.lockfile` is **committed** to the repository
- After **any** change to the build files (dependency, plugin, or `ext` version property), regenerate it through the project workflow:

```bash
cd <repo-root>/<backend-root>
./gradlew dependencies --write-locks
```

- CI fails with `LockOutOfDateException` when the lockfile is stale — the fix is always to regenerate and commit, never to disable locking
- Never edit `gradle.lockfile` by hand

Maven note: versions are locked by the POM itself (plus the Spring Boot BOM) — the equivalent gate is reviewing every `<properties>` version change in the MR.

### Commands

```bash
# Via the project wrapper at its discovered location — invoke only tasks the build defines
cd <repo-root>/<backend-root>
./gradlew tasks                             # discover what exists
./gradlew check                             # full gate
./gradlew <configured-style-check-task>     # e.g. checkstyleMain / spotlessCheck — only if configured
./gradlew jacocoTestCoverageVerification    # only if JaCoCo verification is configured
./gradlew sonar                             # only if Sonar is configured

# Maven equivalents
mvn verify
mvn <configured-plugin-goal>                # e.g. checkstyle:check — only if configured
```

---

## Angular frontend

### Tests — Vitest is the modern target; the current runner is discovered

Automated Angular tests are **required**. The runner is a project fact — Vitest (the Angular CLI default for new projects since Angular 21), Karma+Jasmine (supported brownfield state, a PROJECT_MIGRATION_GAP), or Jest (supported where already configured). No runner configured: PROJECT_TOOLING_GAP. See `11-tests-strategy.md` for the full runner model. Run tests through the project's configured script/builder — **never assume runner-specific CLI flags** (Karma's `--browsers` and Jest's `--watchAll` are runner facts, not universals):

```bash
cd <repo-root>/<frontend-root>
npm test                                    # runs whatever runner angular.json wires
```

### Lint — ESLint + angular-eslint (required target)

Angular linting quality is **required**, and the modern target is **ESLint + angular-eslint**. The actual lint setup **and its enforcement state** are project facts: discover `eslint.config.*` / `.eslintrc*`, the `lint` target in `angular.json`, the package dependencies and the project scripts. A configured but non-blocking or broken lint setup is a **PROJECT_MIGRATION_GAP**: keep it operational as-is for feature work, report the gap, fix the lint system only in a dedicated task. No linting at all: PROJECT_TOOLING_GAP.

Greenfield `eslint.config.mjs` starting point (the selector prefix is discovered from `angular.json` — `app` is the greenfield example):

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

### TypeScript strict + type-check gate (required target)

The quality target is TypeScript `strict` plus Angular `strictTemplates`. The current configuration is discovered from `tsconfig*.json`. If strict mode is currently disabled, that is a **PROJECT_MIGRATION_GAP**: preserve the current configuration, never toggle strict project-wide during an unrelated feature, report the gap — and new code still uses explicit safe typing and introduces no new `any` debt.

Greenfield `tsconfig.json` target (excerpt):

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
cd <repo-root>/<frontend-root>
npx tsc --noEmit          # type-check without build — must pass
```

### Deterministic formatting (required)

A deterministic frontend formatter is **required as a capability**. Discover the configured formatter first (Prettier config, ESLint-driven formatting, or another established tool) — never assume Prettier is already in use. Absent: PROJECT_TOOLING_GAP — no silent installation and no formatter-wide churn during an unrelated feature. Prettier is the greenfield recommendation.

### Production build gate

```bash
cd <repo-root>/<frontend-root>
ng build --configuration production
```

The production build **must pass** — AOT template errors and budget violations only surface here, not in `ng serve`.

### Bundle budgets

`angular.json` (excerpt — thresholds are project facts):

```json
"budgets": [
  { "type": "initial", "maximumWarning": "500kB", "maximumError": "1MB" },
  { "type": "anyComponentStyle", "maximumWarning": "4kB", "maximumError": "8kB" }
]
```

A budget `maximumError` breach fails the build. Raising a budget requires an explicit team decision documented in the MR — never a silent bump.

### Commands

```bash
# Always via the project's configured scripts/targets — direct examples shown
cd <repo-root>/<frontend-root>
npm run lint                                # the project's lint target
npx tsc --noEmit                            # type-check
npm test                                    # discovered runner, project script
ng build --configuration production         # build + budgets
```

---

## Contract gate — OpenAPI ⇄ frontend types

The designated machine-readable contract and the frontend TypeScript types must be **in sync**, per the discovered source mode of `api-contracts.md` (MODE A provider-generated — with or without a tracked snapshot — or MODE B project-owned; no source at all is a PROJECT_TOOLING_GAP; a valid source without frontend automation is an API_CONTRACT_AUTOMATION_GAP).

**Gate**: any MR that changes a `@RestController`, a Request/Response record, or a frontend API interface must show the two sides updated together. Run `/api-contract` (`.claude/commands/api-contract.md`) to check and re-sync; the full workflow is in the `api-contracts.md` rule.

```bash
# Typical drift check where the generated types are versioned — discovered
# generator input/output, resolved from <repo-root>
cd <repo-root>/<frontend-root>
npx @openapitools/openapi-generator-cli generate -g typescript-angular \
  -i <contract-input> -o <generated-output-dir>
test -z "$(git status --porcelain -- <generated-output-dir>)"   # fails on drift, including untracked generated files
```

---

## Pre-commit hooks

`Husky` (Node) or plain bash hooks.

`.husky/pre-commit` (substitute the discovered roots, wrappers and **configured** check tasks/goals). `<repo-root>` is the repository root resolved **once** (e.g. `git rev-parse --show-toplevel` on a Git checkout — an implementation example, not a universal requirement); `<backend-root>`/`<frontend-root>` are repository-root-relative and may be nested at any depth (`apps/server`, `clients/web/angular`…) — the backend root may be the repository root itself. Run project-local commands in a subshell — never rely on `cd ..` to recover the repository root.

The backend branch consumes two placeholders resolved during discovery:

- **`<backend-change-path-pattern>`** — the staged-path pattern meaning "a backend file changed". Git prints staged paths **repository-root-relative, never `./`-prefixed**, so the pattern depends on where the backend root is:
  - backend root is a subdirectory (`back/`, `server/`, `apps/backend/`…): the discovered prefix, e.g. `^back/`;
  - backend root **is** the repository root: never substitute `.` into a `^<backend-root>/` prefix (nothing ever matches `^\./`) — the pattern instead selects the project's **backend-owned paths** (its source directories, `pom.xml` / `build.gradle` / `build.gradle.kts` / `settings.gradle(.kts)`, `gradle/`, wrapper files, backend-owned config…). Which paths those are is a discovered project/build fact, not a universal list.
- **`<backend-precommit-quality-command>`** — the discovered build-tool command: the project wrapper plus **only** its configured checks and discovered test tasks/goals. Gradle project: `<backend-wrapper> <configured-style-check-tasks> <discovered-unit-test-task>`. Maven project: `<maven-wrapper-or-command> <configured-quality-goals> <discovered-test-goals>`. Never emit a Gradle command on a Maven project (or vice versa); never invoke a task/goal the build does not define; a missing required capability stays a **PROJECT_TOOLING_GAP** — the hook installs nothing.

```bash
#!/bin/bash
set -e

# Backend — pattern and command are discovered (see above); works for a nested
# backend root and for a backend at the repository root, Gradle or Maven alike
if git diff --cached --name-only | grep -qE '<backend-change-path-pattern>'; then
  echo "🔍 Backend quality..."
  ( cd "<repo-root>/<backend-root>" &&
    <backend-precommit-quality-command> )
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

GRADLE-ONLY EXAMPLE of a resolved backend command (a nested Gradle backend with configured checks — **not** the universal hook): `./gradlew <configured-style-check-tasks> <discovered-unit-test-task> --quiet`. The Maven equivalent goes through the discovered wrapper/goals, e.g. `./mvnw <configured-quality-goals> <discovered-test-goals>`.

⚠️ **Never `git commit --no-verify`**.

---

## In the project's CI

These gates run in the project's **existing** pipeline, at its quality stage — the toolkit prescribes WHAT must be green, never HOW the pipeline is wired. Backend: the configured style/static checks where the project wires them, the discovered unit suite then the integration suite with their database (service + the project's own profile/datasource variables), coverage evidence. Frontend: lint, `tsc --noEmit`, production build, tests with coverage through the discovered runner. CI topology is a **discovered fact**: read the project's actual pipeline to know which jobs exist and which ones block — never invent a job name or assert that a check is blocking without the pipeline proving it.

## Makefile to orchestrate everything (greenfield example)

`Makefile` (project root — **greenfield only**; a project that already has its own targets keeps them; substitute the discovered roots and configured tasks):

```makefile
.PHONY: quality test check

quality:
	cd backend && ./gradlew check -x test
	cd frontend && npm run lint && npx tsc --noEmit

test:
	cd backend && ./gradlew check
	cd frontend && npm test

check: quality test
	cd frontend && npx ng build --configuration production
```

---

## Gate summary before merge

Before any MR is merged, all of the following must be green locally and in CI:

1. Backend aggregate gate (`./gradlew check` / `mvn verify`): compile, discovered test suites, configured style/static checks, configured coverage verification
2. `gradle.lockfile` up to date with the build files — where dependency locking is enabled
3. Frontend lint green per the project's enforcement state + `npx tsc --noEmit`
4. Frontend tests green (discovered runner) + `ng build --configuration production` passes budgets
5. API contract and frontend types in sync per the discovered source mode (`/api-contract`)
6. Sonar quality gate passed on new code — if Sonar is configured

---

## Anti-patterns

- ❌ `--no-verify` on git commit
- ❌ Invoking a build task the project does not define (`spotlessCheck`, `checkstyleMain`, a custom test split…) instead of discovering the configured checks
- ❌ Disabling an ESLint or style rule without documenting why (ticket reference)
- ❌ `any` in TypeScript code, bare `@SuppressWarnings` in Java
- ❌ Raising a bundle budget silently to make the build pass
- ❌ Regenerating the lockfile "to fix CI" without understanding which dependency moved
- ❌ Updating a backend record without updating the frontend contract side (or vice versa)
- ❌ Disabled tests (`xit`, `@Disabled`) without a re-enable ticket
- ❌ CI pipeline that passes with ignored warnings
- ❌ Silently rewriting a configured-but-broken lint/quality setup during unrelated work
