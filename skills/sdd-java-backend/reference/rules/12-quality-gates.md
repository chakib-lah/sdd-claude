# Quality gates — Java / Spring Boot

> **Layer 2 — Specific to the Java/Spring Boot stack.**

---

## Strictness levels

Three levels to choose from at SDD installation time:

| Level | Profile | Gates |
|---|---|---|
| **Soft** | Recent project just starting | Format check + compile warnings, coverage informative |
| **Medium** | Project being stabilized | Checkstyle blocking, JaCoCo ≥ 60% on new code |
| **Strict** | Mature, demanding code | Checkstyle + Sonar quality gate blocking, JaCoCo ≥ 80%, zero new warnings |

**Default recommendation**: Medium, moving to Strict once the baseline is clean.

## Mandatory tools

### Formatting — Spotless (google-java-format) or Checkstyle

Spotless, Gradle:

```groovy
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
```

Checkstyle, Gradle (alternative or complement):

```groovy
plugins {
    id 'checkstyle'
}

checkstyle {
    toolVersion = '10.21.1'
    configFile = file('config/checkstyle/checkstyle.xml')
    maxWarnings = 0
}
```

Maven equivalent:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <configuration>
        <configLocation>config/checkstyle/checkstyle.xml</configLocation>
        <failOnViolation>true</failOnViolation>
    </configuration>
</plugin>
```

### Coverage gate — JaCoCo

```groovy
plugins {
    id 'jacoco'
}

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

With the `unitTest`/`integrationTest` split (see `.claude/rules/11-tests-strategy.md`),
`jacocoTestReport` and `jacocoTestCoverageVerification` read `build/jacoco/test.exec`
by default and silently skip when only the split tasks ran. Wire the execution data
explicitly so both tasks aggregate the split tasks' exec files:

```groovy
tasks.named('jacocoTestReport') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
    dependsOn 'unitTest', 'integrationTest'
}

tasks.named('jacocoTestCoverageVerification') {
    executionData fileTree(layout.buildDirectory).include('jacoco/*.exec')
}
```

### SonarQube

```groovy
plugins {
    id 'org.sonarqube' version '6.0.1.5171'
}

sonar {
    properties {
        property 'sonar.host.url', 'https://sonar.example.com'   // adapt to your instance
        property 'sonar.projectKey', 'my-project'
        property 'sonar.coverage.jacoco.xmlReportPaths',
                 'build/reports/jacoco/test/jacocoTestReport.xml'
    }
}
```

The token comes from the `SONAR_TOKEN` environment variable — never committed.

### Error Prone / NullAway (optional, recommended on strict projects)

Error Prone catches bug patterns at compile time; NullAway enforces null-safety
(pairs well with JSpecify `@NullMarked` on Spring Boot 4 projects). Add them via
the `net.ltgt.errorprone` Gradle plugin once the codebase compiles warning-free.

## Execution commands

```bash
# Full gate (compile + tests + checkstyle + coverage verification)
./gradlew check

# Formatting / style only
./gradlew checkstyleMain

# Coverage threshold only
./gradlew jacocoTestCoverageVerification

# Sonar analysis
./gradlew sonar

# Maven equivalents
mvn verify
mvn checkstyle:check
mvn sonar:sonar
```

## Dependency-locking gate (Gradle)

- `gradle.lockfile` is **committed** to the repository
- After **any** change to `build.gradle` (add/bump/remove a dependency, plugin, or
  `ext` version property), regenerate it:

```bash
./gradlew dependencies --write-locks
```

- CI fails with `LockOutOfDateException` when the lockfile is stale — the fix is
  always to regenerate and commit, never to disable locking
- Never edit `gradle.lockfile` by hand

Maven note: versions are locked by the POM itself (plus the Spring Boot BOM), so no
separate lockfile is needed — the equivalent gate is reviewing every `<properties>`
version change in the MR.

## Pre-commit hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "🎨 Format check..."
./gradlew spotlessCheck --quiet

echo "🔍 Checkstyle..."
./gradlew checkstyleMain --quiet

echo "🧪 Unit tests..."
./gradlew unitTest --quiet

echo "✅ Quality gates OK"
```

⚠️ **Never `git commit --no-verify`**.

## Test coverage

Target: progressive thresholds based on maturity.

```groovy
jacocoTestReport {
    reports {
        xml.required = true
        html.required = true
    }
    afterEvaluate {
        classDirectories.setFrom(files(classDirectories.files.collect {
            fileTree(dir: it, exclude: [
                '**/config/**',
                '**/dto/**',            // records: trivial
                '**/*Application.class'
            ])
        }))
    }
}
```

Suggested thresholds:
- Start: 50% overall
- 6 months: 70% overall, 90% on business services
- 1 year: 80% overall

Check in CI:

```bash
./gradlew jacocoTestReport jacocoTestCoverageVerification
```

## Typical GitLab CI

```yaml
image: gradle:9-jdk21

stages:
  - quality
  - test

variables:
  GRADLE_USER_HOME: "$CI_PROJECT_DIR/.gradle"

quality:
  stage: quality
  script:
    - ./gradlew checkstyleMain spotlessCheck --no-daemon
  cache:
    key: gradle-$CI_COMMIT_REF_SLUG
    paths:
      - .gradle/caches

unit-tests:
  stage: test
  script:
    - ./gradlew unitTest --no-daemon
  artifacts:
    reports:
      junit: build/test-results/unitTest/*.xml

integration-tests:
  stage: test
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
    - ./gradlew integrationTest jacocoTestReport --no-daemon
```

The postgres service needs `POSTGRES_DB`/`POSTGRES_USER`/`POSTGRES_PASSWORD` or the
container never starts. `jacocoTestReport` runs in the integration job because it
depends on both split tasks (see the `executionData` wiring above) — the unit-tests
job alone has no database for `integrationTest`.

Adapt image and services to the project (Testcontainers needs a Docker-capable runner).

## Ignoring violations

If a Checkstyle violation cannot be resolved immediately, use a suppressions file:

```xml
<!-- config/checkstyle/suppressions.xml -->
<suppressions>
    <!-- Legacy adapter, planned refactor: PROJ-123 -->
    <suppress checks="MethodLength"
              files="LegacyOrderAdapter\.java"/>
</suppressions>
```

Always **document the reason** and the **intent to resolve** (ticket reference) next
to each suppression. Same rule for `@SuppressWarnings` in code: a bare suppression
without a comment is rejected in review.

## Baseline mode for brownfield projects

- **SonarQube**: configure the quality gate on **new code** only (Clean as You Code).
  Existing issues stay visible but do not block; every MR must keep new code clean.
- **Checkstyle**: freeze existing violations in `suppressions.xml` with a documented
  intent per entry, then shrink the file progressively — never grow it.
- **JaCoCo**: start with the current coverage as the `minimum`, ratchet it up as
  tests are added (lowering the threshold requires an explicit team decision).

The goal is to **shrink the baseline** progressively, not to ignore it.

## Gate summary before merge

Before any MR is merged, all of the following must be green locally and in CI:

1. `./gradlew check` (compile, tests, style, coverage verification)
2. `gradle.lockfile` up to date with `build.gradle`
3. Sonar quality gate passed on new code (if Sonar is configured)
