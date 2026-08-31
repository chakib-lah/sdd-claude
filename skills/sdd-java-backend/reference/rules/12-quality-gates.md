# Quality gates — Java / Spring Boot

> **Layer 2 — Specific to the Java/Spring Boot stack.**

---

## Required capabilities vs discovered parameters

This rule names the quality capabilities **required** by the Java backend skill. Their concrete parameters are **project facts** — discovered from the repository, never edited into this Layer-2 rule. The coordinates are discovered too: `<repo-root>` is the repository root resolved **once** (e.g. `git rev-parse --show-toplevel` on a Git checkout — an implementation example, not a universal requirement); `<backend-root>` is the repository-root-relative directory where the backend build lives — it may be nested at any depth (`backend/`, `server/`, `apps/backend/`…) **or be the repository root itself**. The build tool (Gradle Groovy/Kotlin DSL or Maven), the wrapper location (`gradlew` / `mvnw`, possibly at the repository root), the module structure (Maven multi-module, Gradle multi-project) and the actually configured tasks/goals are all read from the build files — never assumed. The wrapper location and the backend root are **independent facts** (a root wrapper may drive a nested module through a module/project selector); operational commands are therefore **complete discovered invocations** — wrapper executable at its actual location + working directory + module selector + task/goal + configured options — never "cd to the backend root and run `./gradlew`" as a universal shape.

| Capability | Status | Current parameters (discovered) |
|---|---|---|
| Automated tests (JUnit 5) | **Required** | build tool, wrapper location, actual tasks/goals, suite convention (see `.claude/rules/11-tests-strategy.md`) |
| Static/style quality | **Required** | configured implementation: Checkstyle, Spotless, Sonar rules, Error Prone, PMD, other equivalent |
| Coverage / quality evidence | **Required** | configured tool (JaCoCo is the common example), thresholds, report wiring |
| Deterministic formatting | **Required** | configured formatter (Spotless, enforced IDE/editorconfig setup, other) |
| Build verification | **Required** | Gradle `check` / Maven `verify` via the project wrapper |
| Dependency quality | **Required** | Gradle dependency locking **where enabled**, BOM discipline, security audit tooling |
| Machine-readable API contract | **Required where the backend exposes a REST API** | discovered provider/export mechanism or project-owned OpenAPI document (see below) |

**Discovery is not optionality.** For every required capability:

- **Implementation configured** → use the configured implementation.
- **Equivalent valid implementation configured** → use it; never demand one named tool when the project satisfies the capability differently.
- **Required capability absent** → **PROJECT_TOOLING_GAP** — the capability remains required; installing/configuring it is a dedicated tooling change, never a silent side effect of unrelated feature work. Absence is never an accepted project convention.
- **Present but below-target or non-blocking** → the current setup stays operational for feature work; the gap is reported and closed in a dedicated task — never silently rewritten during unrelated work.

Layer 3 (`.claude/rules/project-quality.md`) may specialize parameters durably — thresholds, rollout/ratchet state, warning budgets, enforcement staging — but can never negate a required capability. There is no state "absent, therefore not required", and no strictness profile or project maturity level turns a required capability off.

---

## Aggregate gate

The single backend gate is the build tool's verification lifecycle, run through the **discovered complete invocation**:

```bash
<backend-aggregate-gate-command>   # resolves to Gradle `check` or Maven `verify` through the
                                   # discovered wrapper location, working directory and module selector
# Example resolutions (valid shapes, NOT universal syntax):
#   <repo-root>/gradlew :apps:backend:check    — root wrapper + nested Gradle module
#   cd <backend-root> && ./gradlew check       — wrapper inside the backend root
#   <repo-root>/mvnw -pl <module> verify       — root Maven wrapper + module targeting
#   cd <backend-root> && ./mvnw verify         — wrapper inside the Maven module
```

Everything blocking must be wired into it: the project's discovered test tasks/goals, its configured style/static-analysis checks, its coverage verification. Which tasks exist is a **project fact** — list them (`./gradlew tasks`, or the POM's plugins) before invoking anything; never invoke a task (`spotlessCheck`, `checkstyleMain`, a custom test split…) that the build does not define.

## Static analysis and style — discovered implementation

Static/style quality and deterministic formatting are **required as capabilities**; the implementation is discovered. Real projects satisfy them differently: Checkstyle, Spotless, Sonar rules on new code, Error Prone, PMD, an enforced editorconfig/IDE setup, or another configured equivalent. Run **only the project's configured checks** through its wrapper. No configured static/style check or formatter at all: **PROJECT_TOOLING_GAP** — report it; setting one up is a dedicated tooling task, never a silent install during a feature.

Greenfield defaults (**GREENFIELD ONLY** — an existing project keeps its own configured implementation):

```groovy
// Spotless (formatting)
plugins {
    id 'com.diffplug.spotless' version '7.0.2'
}

spotless {
    java {
        googleJavaFormat()
        removeUnusedImports()
        target 'src/**/*.java'
    }
}

// Checkstyle (style)
plugins {
    id 'checkstyle'
}

checkstyle {
    toolVersion = '10.21.1'
    configFile = file('config/checkstyle/checkstyle.xml')
    maxWarnings = 0
}
```

Maven greenfield equivalent: `maven-checkstyle-plugin` with `<failOnViolation>true</failOnViolation>`.

## Coverage — JaCoCo (common discovered example)

Coverage evidence is required; JaCoCo is the common Gradle/Maven implementation — discover its configuration and thresholds. Greenfield verification example:

```groovy
jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                counter = 'LINE'
                value = 'COVEREDRATIO'
                minimum = 0.60          // the enforced value is the project's configured one
            }
        }
    }
}

tasks.named('check') {
    dependsOn 'jacocoTestCoverageVerification'
}
```

With a split unit/integration setup (see `.claude/rules/11-tests-strategy.md`), `jacocoTestReport` and `jacocoTestCoverageVerification` read `build/jacoco/test.exec` by default and silently skip when only the split tasks ran. Wire the execution data explicitly so both tasks aggregate the split tasks' exec files:

```groovy
tasks.named('jacocoTestReport') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
tasks.named('jacocoTestCoverageVerification') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
```

The enforced thresholds are the project's **configured** ones; never regress coverage on changed code. Greenfield suggestion: 60% to start, 80% at maturity, 90% on business services. Exclude trivial generated code (`**/dto/**` records, `**/config/**`, `*Application`).

## SonarQube (discovered example)

Where the project wires Sonar, it can carry the static-analysis and coverage-evidence capabilities:

```groovy
sonar {
    properties {
        property 'sonar.host.url', 'https://sonar.example.com'   // adapt to your instance
        property 'sonar.projectKey', 'my-project'
        property 'sonar.coverage.jacoco.xmlReportPaths',
                 'build/reports/jacoco/test/jacocoTestReport.xml'
    }
}
```

Token from the `SONAR_TOKEN` environment variable — never committed. On brownfield projects, configure the quality gate on **new code** only (Clean as You Code).

## Error Prone / NullAway (optional equivalents)

Error Prone catches bug patterns at compile time; NullAway enforces null-safety (pairs well with JSpecify `@NullMarked` on Spring Boot 4 projects). Valid additional implementations of the static-quality capability — add them via the `net.ltgt.errorprone` Gradle plugin in a dedicated tooling task, once the codebase compiles warning-free.

## Dependency locking gate — where enabled

Gradle dependency locking is the **greenfield recommendation**, and whether it is enabled is a **project fact** (`dependencyLocking` in the build, `gradle.lockfile` present) — not every valid Gradle project uses it. **When locking is enabled**:

- `gradle.lockfile` is **committed** to the repository
- After **any** change to the build files (dependency, plugin, or `ext` version property), regenerate it through the **discovered project workflow** — a dedicated project script/task where one exists, otherwise the standard mechanism through the discovered complete build invocation:

```bash
<dependency-lock-regeneration-command>
# e.g. resolves to: <backend-build-invocation> dependencies --write-locks
# (root wrapper + module selector, or wrapper inside the backend root — as discovered)
```

- CI fails with `LockOutOfDateException` when the lockfile is stale — the fix is always to regenerate and commit, never to disable locking
- Never edit `gradle.lockfile` by hand

**When locking is absent**: do not pretend `gradle.lockfile` exists, and never enable locking silently during unrelated feature work — dependency reproducibility then rests on the project's other discovered discipline (pinned versions, BOM), and adopting locking is a dedicated tooling decision.

Maven note: versions are locked by the POM itself (plus the Spring Boot BOM) — the equivalent gate is reviewing every `<properties>` version change in the MR.

## Backend API contract capability

A machine-readable API contract is **required where the backend exposes a REST API**; its implementation is a set of **project facts** — discover, never assume:

- **Provider-generated contract**: springdoc-openapi is the common Spring Boot example, but any real configured provider/export mechanism (runtime docs endpoint, build-time export plugin, project script) is valid. Task names, endpoints, ports and artifact paths are configured project facts.
- **Project-owned hand-written OpenAPI document** (JSON or YAML) designated as the source of truth: equally valid — validate and evolve it through the project's workflow; no provider is required.
- **Provider metadata** (springdoc `@Tag` / `@Operation` / `@ApiResponse` / `@Schema`) is provider-specific — required only where that provider owns the contract **and** the project's convention applies it, never universally.
- **Tracked snapshot**: whether a provider-generated contract is versioned in Git is a project fact — never require or create a tracked snapshot as a side effect of validation or scaffolding.
- **No machine-readable contract mechanism at all** on a backend that **does expose a REST API**: **PROJECT_TOOLING_GAP** — this is the gap `/java-controller` reports here; closing it (choosing a provider or authoring a project-owned document) is a dedicated tooling/contract task, never a silent install.
- **No REST API at all** (batch application, scheduled worker, message consumer, event processor, non-HTTP integration service…): the contract capability is **not applicable** — applicability, not optionality: report no gap, install no provider, create no OpenAPI document. The requirement stays fully intact the moment the backend exposes REST endpoints.

This backend-only skill carries **no frontend/client synchronization requirement**.

## Execution commands

```bash
# <backend-build-invocation> = the discovered complete invocation: wrapper executable at its
# actual location + working directory + module/project selector where multi-module
# (e.g. `<repo-root>/gradlew :apps:backend:…`, `cd <backend-root> && ./gradlew …`,
#  `<repo-root>/mvnw -pl <module> …`, `cd <backend-root> && ./mvnw …`)
# Never assume wrapper cwd == backend root. Invoke only tasks/goals the build defines.

<backend-build-invocation> tasks                           # Gradle: discover what exists
<backend-aggregate-gate-command>                           # full gate: Gradle `check` / Maven `verify`
<backend-build-invocation> <configured-style-check-task>   # e.g. checkstyleMain / spotlessCheck — only if configured
<backend-build-invocation> <configured-coverage-task>      # e.g. jacocoTestCoverageVerification — only if configured
<backend-build-invocation> sonar                           # only if Sonar is configured
<backend-build-invocation> <configured-plugin-goal>        # Maven: e.g. checkstyle:check — only if configured
```

## Pre-commit hooks

The hook consumes two placeholders resolved during discovery:

- **`<backend-change-path-pattern>`** — the staged-path pattern meaning "a backend file changed". Git prints staged paths **repository-root-relative, never `./`-prefixed**, so:
  - backend root is a subdirectory (`backend/`, `server/`, `apps/backend/`…): the discovered prefix, e.g. `^server/`;
  - backend root **is** the repository root: never substitute `.` into a `^<backend-root>/` prefix (nothing ever matches `^\./`) — the pattern instead selects the project's **backend-owned paths** (its source directories, `pom.xml` / `build.gradle` / `build.gradle.kts` / `settings.gradle(.kts)`, `gradle/`, wrapper files, backend-owned config…), a discovered project/build fact, not a universal list.
- **`<backend-precommit-quality-command>`** — the discovered **complete invocation**: it encodes its own wrapper location, working directory and module/project selector, plus **only** the configured checks and discovered test tasks/goals. Gradle project: `<backend-build-invocation> <configured-style-check-tasks> <discovered-unit-test-task>`. Maven project: `<backend-build-invocation> <configured-quality-goals> <discovered-test-goals>`. Never emit a Gradle command on a Maven project (or vice versa); never invoke a task/goal the build does not define; never assume the wrapper sits in the backend root; a missing required capability stays a **PROJECT_TOOLING_GAP** — the hook installs nothing.

```bash
#!/bin/bash
set -e

# Backend — pattern and command are discovered (see above); works for a nested
# backend root, a backend at the repository root, a root wrapper driving a nested
# module, or a wrapper inside the backend root — Gradle or Maven alike
if git diff --cached --name-only | grep -qE '<backend-change-path-pattern>'; then
  echo "🔍 Backend quality..."
  ( <backend-precommit-quality-command> )   # complete discovered invocation, run in a subshell
fi

echo "✅ Quality gates OK"
```

GREENFIELD ONLY / GRADLE-ONLY example of a resolved command (a Gradle project with configured Spotless/Checkstyle and a discovered `unitTest` task — **not** the universal hook): `./gradlew spotlessCheck checkstyleMain unitTest --quiet`. The Maven equivalent goes through the discovered wrapper/goals, e.g. `./mvnw <configured-quality-goals> <discovered-test-goals>`.

⚠️ **Never `git commit --no-verify`**.

## In the project's CI

These gates run in the project's **existing** pipeline, at its quality stage — the toolkit prescribes WHAT must be green, never HOW the pipeline is wired: the configured style/static checks where the project wires them, the discovered unit suite then the integration suite with their database (service + the project's own profile/datasource variables), coverage evidence. CI topology is a **discovered fact**: read the project's actual pipeline to know which jobs exist and which ones block — never invent a job name or assert that a check is blocking without the pipeline proving it. Caching the Gradle/Maven dependency cache (e.g. via `GRADLE_USER_HOME`) avoids re-downloading dependencies on every job.

## Ignoring violations

Where Checkstyle is the configured implementation and a violation cannot be resolved immediately, use a suppressions file:

```xml
<!-- config/checkstyle/suppressions.xml -->
<suppressions>
    <!-- Legacy adapter, planned refactor: PROJ-123 -->
    <suppress checks="MethodLength"
              files="LegacyOrderAdapter\.java"/>
</suppressions>
```

Always **document the reason** and the **intent to resolve** (ticket reference) next to each suppression. Same rule for `@SuppressWarnings` in code: a bare suppression without a comment is rejected in review.

## Baseline mode for brownfield projects

Brownfield state is never an exemption — the required capabilities stay required; the **enforcement parameters** ratchet:

- **SonarQube** (where configured): quality gate on **new code** only (Clean as You Code). Existing issues stay visible but do not block; every MR must keep new code clean.
- **Checkstyle** (where configured): freeze existing violations in `suppressions.xml` with a documented intent per entry, then shrink the file progressively — never grow it.
- **JaCoCo** (where configured): start with the current coverage as the `minimum`, ratchet it up as tests are added (lowering the threshold requires an explicit team decision).

The goal is to **shrink the baseline** progressively, not to ignore it. Document the rollout state in Layer 3 (`.claude/rules/project-quality.md`).

## Gate summary before merge

Before any MR is merged, all of the following must be green locally and in CI:

1. Backend aggregate gate (`<backend-aggregate-gate-command>` — Gradle `check` / Maven `verify` through the discovered complete invocation): compile, discovered test suites, configured style/static checks, configured coverage verification
2. `gradle.lockfile` up to date with the build files — where dependency locking is enabled
3. Sonar quality gate passed on new code — if Sonar is configured
4. REST endpoint changes represented in the machine-readable contract via the discovered mechanism (`/java-controller`) — or the PROJECT_TOOLING_GAP reported

## Anti-patterns

- ❌ `--no-verify` on git commit
- ❌ Invoking a build task/goal the project does not define (`spotlessCheck`, `checkstyleMain`, a custom test split…) instead of discovering the configured checks
- ❌ Silently installing or enabling a quality tool (formatter, linter, locking, provider) during unrelated feature work
- ❌ Treating a required capability as optional because the project is brownfield or "just starting"
- ❌ Disabling a style rule without documenting why (ticket reference)
- ❌ Regenerating the lockfile "to fix CI" without understanding which dependency moved — where locking is enabled
- ❌ Editing `gradle.lockfile` by hand — where locking is enabled
- ❌ Demanding a `gradle.lockfile` on a project that has not enabled dependency locking
- ❌ CI pipeline that passes with ignored warnings
- ❌ Silently rewriting a configured-but-broken quality setup during unrelated work
