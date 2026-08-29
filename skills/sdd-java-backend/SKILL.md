---
name: sdd-java-backend
description: Generates a Spec-Driven Development framework for a Java/Spring Boot backend project (without frontend framework). Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project using Java + Spring Boot, Spring Data JPA/Hibernate, and Flyway or Liquibase migrations - but NOT a separate frontend framework like Angular/React/Vue. Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "génère le framework SDD", "installe SDD" when applied to a project where build.gradle or pom.xml contains org.springframework.boot or spring-boot-starter dependencies. Detects brownfield/greenfield mode. Provides fine-grained auxiliary commands (java-entity, java-service, java-controller, java-test). Adds migration-guard for brownfield projects.
license: MIT
---

# SDD Framework — Java / Spring Boot Backend

This skill installs a complete Spec-Driven Development framework into a Java/Spring Boot backend project by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project uses Spring Boot (`build.gradle` or `pom.xml` contains `org.springframework.boot` / `spring-boot-starter`)
- The project may use Spring Data JPA/Hibernate and Flyway or Liquibase, but does NOT have a separate Angular/React/Vue frontend

Do NOT use when:
- The project uses Spring Boot + Angular → use `sdd-java-angular` skill instead
- The project uses PHP/Symfony → use `sdd-php-symfony` skill instead
- The project is pure PHP without framework → use `sdd-php-backend` skill instead
- The project uses Angular + Node.js → use `sdd-angular-node` skill instead
- The project is Java WITHOUT Spring Boot (Quarkus, Micronaut, Jakarta EE) → no dedicated skill yet, adapt manually

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: no `src/main/java/`, no `build.gradle` / `pom.xml`, no lockfile
- **Brownfield**: existing code, `build.gradle` or `pom.xml` present, architecture in place

Announce in chat:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield)

Analyze and report on:

**Stack detected**
```
build tool               : Gradle x.x (wrapper) / Maven x.x — gradle.lockfile: [yes/no]
java                     : x
spring-boot              : x.x.x
hibernate                : x.x.x
flyway / liquibase       : x.x.x
mapstruct / lombok       : x.x.x / x.x.x
springdoc-openapi        : x.x.x
junit / mockito          : x.x.x / x.x.x
testcontainers / emb. DB : [testcontainers x.x.x / embedded PostgreSQL / none]
```

**Backend architecture**
- Package structure: layered (`controller/service/repository`) or hexagonal (`domain/application/infrastructure`)?
- Controllers: thin and delegating, or business logic embedded?
- Services: behind interfaces or concrete classes injected directly?
- Mapping: MapStruct mappers, manual mapping, or entities exposed directly?
- DTOs: records, Lombok classes, validation annotations?

**Existing tests**
- Unit/integration split: naming pattern (`*IT`, `*IntTest`), separate source set or Gradle/Maven task?
- Test directories and naming conventions (`*Test.java`)
- Coverage tooling (JaCoCo) and estimated coverage

**CI/CD and tooling**
- `.gitlab-ci.yml` or GitHub Actions workflows
- JaCoCo, Sonar, Checkstyle/Spotless configuration
- Build tasks or Maven profiles dedicated to quality

**Gaps and debt**
- Entities or services without tests
- No committed dependency lockfile
- Endpoints without springdoc annotations
- Migrations off naming convention or without documented rollback path

Then ask 4 clarification questions:
1. Team conventions not visible in code?
2. Painful repetitive workflows to automate?
3. Company/client constraints (security, architecture rules)?
4. Generate retrospective specs for existing features, or only new?

For greenfield, ask the 11 greenfield questions.

### Phase 2 — Propose structure

Display the structure to be deployed and wait for validation.

### Phase 3 — Deploy files

Copy from `reference/` to project's `.claude/`, in this order:

```
.claude/agents/spec-writer.md
.claude/agents/plan-architect.md
.claude/agents/task-decomposer.md
.claude/agents/test-generator.md
.claude/agents/code-reviewer.md
.claude/rules/00-sdd-framework.md
.claude/rules/02-git-conventions.md
.claude/rules/03-security.md
.claude/rules/04-code-quality.md
.claude/rules/10-code-conventions.md
.claude/rules/11-tests-strategy.md
.claude/rules/12-quality-gates.md
.claude/rules/jpa-conventions.md
.claude/rules/migration-guard.md          (brownfield only)
.claude/sdd/_template/spec.md
.claude/sdd/_template/plan.md
.claude/sdd/_template/tasks.md
.claude/sdd/_template/notes.md
.claude/sdd/_template/jira-story-fr.md
.claude/sdd/_template/jira-story-en.md
.claude/sdd/_template/spec-doc-fr.md
.claude/sdd/_template/spec-doc-en.md
.claude/sdd/README.md
.claude/sdd/_archive/.gitkeep
.claude/commands/sdd-start.md
.claude/commands/sdd-spec.md
.claude/commands/sdd-clarify.md
.claude/commands/sdd-spec-check.md
.claude/commands/sdd-plan.md
.claude/commands/sdd-tasks.md
.claude/commands/sdd-implement.md
.claude/commands/sdd-verify.md
.claude/commands/sdd-review.md
.claude/commands/sdd-mr.md
.claude/commands/sdd-archive.md
.claude/commands/sdd-status.md
.claude/commands/sdd-hotfix.md
.claude/commands/sdd-upgrade.md
.claude/commands/sdd-changelog.md
.claude/commands/sdd-revert.md
.claude/commands/retro-spec.md
.claude/commands/java-entity.md
.claude/commands/java-service.md
.claude/commands/java-controller.md
.claude/commands/java-test.md
```

> **CI/CD**: every project keeps its own pipeline. The rules in `.claude/rules/12-quality-gates.md` state what must be green at the quality stage — wire those checks into your existing CI.

### Phase 4 — Dispose of the detected project facts (Layer 2 stays untouched)

The Layer-2 files just deployed are **skill-owned**: immediately after installation the project's Layer 2 is **byte-identical to `reference/`**, and it stays that way — never edit a deployed Layer-2 rule with project findings. Instead, dispose of every Phase 1 finding by ownership:

- **Discoverable on demand — do not persist**: Java, Spring Boot, JUnit, Hibernate and Flyway/Liquibase versions, the build tool, and the exact Gradle/Maven test commands (`build.gradle`/`build.gradle.kts`/`pom.xml`, `gradle.lockfile`), Checkstyle/Sonar/JaCoCo configuration (their config files). Commands read these canonical sources when they need them. (Diagnostic aid, already stack knowledge in `jpa-conventions.md`: Flyway 10+ splits PostgreSQL support into `flyway-database-postgresql`; Flyway 9 ships it in core.)
- **Durable project context → Layer 3**: the detected architecture (hexagonal or standard) and the unit/integration naming split the team uses (`*IT` / `*IntTest`) — `.claude/rules/project-architecture.md` / `.claude/rules/project-testing.md`.
- **Project policies → Layer 3**: the dependency-lockfile policy and quality-gate targets — `.claude/rules/project-quality.md`.
- **Diagnostic only**: the Phase 1 stack report is announced in the chat and not persisted. Report versions **as found** — never force an upgrade; modern recommendations (Java 25 LTS or 21, Spring Boot 4.1.x or 3.5.x) apply only to greenfield scaffolding.

Create a Layer-3 file **only if at least one durable fact or policy needs that subject**; when an existing project rule already owns the subject, reuse it — never create empty or placeholder project files, and never create a second owner for the same subject.

### Phase 5 — Announce completion

```
✅ SDD Framework Java/Spring Boot installed.

SDD agents deployed:
  spec-writer · plan-architect · task-decomposer
  test-generator · code-reviewer

Next steps:
- Create your domain skills in .claude/skills/ if needed
- Start a feature: /sdd-start <FEATURE-ID>-<description>
```

## Critical rules

- **Never modify the source code** of the project. Only `.claude/` is touched.
- **Always wait for validation** before deploying.
- **Use `reference/` files as source of truth**.
- **Never edit a deployed Layer-2 rule with project facts** — Layer 2 stays byte-identical to `reference/` (that is what lets `/sdd-upgrade` keep it in sync with the skill); project truth goes to Layer 3 (Phase 4).
- **Migration-guard** is brownfield-only.

## What this skill does NOT do

- Does not create project-specific skills (those go in `.claude/skills/`)
- Does not configure CI/CD
- Does not install Spring Boot starters or Gradle/Maven dependencies
- Does not write production code
