---
name: sdd-java-angular
description: Generates a Spec-Driven Development framework for a full-stack project combining Java/Spring Boot backend AND Angular frontend. Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project where the backend uses Spring Boot (build.gradle or pom.xml contains org.springframework.boot) AND the frontend uses Angular (package.json has @angular/core). Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "create SDD framework", "génère le framework SDD", "installe SDD" when applied to a Spring Boot + Angular full-stack project. Detects brownfield/greenfield. Provides fine-grained auxiliary commands for both backend (java-entity, java-service, java-controller, java-test) and frontend (angular-component, angular-service, angular-test) plus api-contract for OpenAPI sync via springdoc. Adds migration-guard for brownfield.
license: Proprietary
---

# SDD Framework — Java/Spring Boot + Angular Full-Stack

This skill installs a complete Spec-Driven Development framework into a full-stack Spring Boot + Angular project by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project uses a Spring Boot backend (`build.gradle` or `pom.xml` contains `org.springframework.boot`)
- The project uses an Angular frontend (`package.json` contains `@angular/core`)
- Typically a `backend/` + `frontend/` structure or similar separation

Do NOT use when:
- Backend is Spring Boot but no Angular → use `sdd-java-backend` instead
- Frontend is Angular but backend is Node.js → use `sdd-angular-node` instead
- Frontend is Angular but backend is Symfony → use `sdd-symfony-angular` instead
- Backend is Symfony without a frontend framework → use `sdd-php-symfony` instead
- Frontend is React/Vue (not Angular) → no specific skill yet

## Process

### Phase 0 — Detect mode

Inspect the project root (usually two sides: `backend/` + `frontend/` directories or equivalents):

- **Greenfield**: minimal code, no `build/` or `target/`, no `node_modules/`
- **Brownfield**: existing backend + frontend in place

Announce:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Backend: Java [version] / Spring Boot [version] [+ notable starters]
Frontend: Angular [version] [+ notable libs]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield)

#### 1.1 — Java/Spring Boot backend

```
build tool               : Gradle x.x (wrapper) / Maven x.x — lockfile: [yes/no]
java                     : x
spring-boot              : x.x.x
hibernate                : x.x.x
flyway / liquibase       : x.x.x
mapstruct / lombok       : x.x.x / x.x.x
springdoc-openapi        : x.x.x
junit / mockito          : x.x.x / x.x.x
```

- Package structure: layered (`controller/service/repository`) or hexagonal?
- Controllers thin and delegating, or business logic embedded?
- Mapping: MapStruct, manual, or entities exposed directly?
- Existing tests and unit/integration split (`*IT` / `*IntTest`)

#### 1.2 — Angular frontend

```
angular/core/version     : x.x.x
node/version             : x.x.x (from package.json engines or .nvmrc)
typescript/version       : x.x.x
style/ui-lib             : [Material / PrimeNG / Tailwind / custom / none]
state management         : [Signals / NgRx / plain RxJS / other]
```

- Standalone components or NgModules?
- zone.js or zoneless change detection?
- Signals (Angular 17+) or classic RxJS?
- Tests: Karma+Jasmine or Jest?
- E2E: Cypress, Playwright?
- Runtime config: `assets/config.json` or `environments/`? `proxy.conf.json` present?

#### 1.3 — Spring Boot ↔ Angular integration

- API contracts: springdoc-openapi installed? Contract generated?
- Frontend types: hand-written or generated from OpenAPI?
- Auth: JWT, session, SSO?
- CORS: `@CrossOrigin`, `WebMvcConfigurer`, gateway-level?
- Uniform API error format across endpoints?

#### 1.4 — Identified gaps

- Endpoints without springdoc annotations
- Hand-written TypeScript types drifting from the backend DTOs
- Angular components without spec
- Naming inconsistencies between backend and frontend
- Non-uniform API error format

Then ask the 4 clarification questions:
1. Team conventions not visible in the code?
2. Most painful repetitive workflows to automate?
3. Specific constraints (security, architecture)?
4. Retrospective specs for existing features or only new ones?

For greenfield, ask the 11 discovery questions.

### Phase 2 — Propose structure

Display the complete structure and **wait for validation**.

### Phase 3 — Deploy files

Copy from `reference/` to project's `.claude/`, in this order:

```
.claude/agents/spec-writer.md
.claude/agents/plan-architect.md
.claude/agents/task-decomposer.md
.claude/agents/test-generator.md
.claude/agents/code-reviewer.md
.claude/rules/00-sdd-framework.md
.claude/rules/01-constitution.md          (skeleton — never overwrite an existing one)
.claude/rules/02-git-conventions.md
.claude/rules/03-security.md
.claude/rules/10-code-conventions.md
.claude/rules/11-tests-strategy.md
.claude/rules/12-quality-gates.md
.claude/rules/jpa-conventions.md
.claude/rules/angular-conventions.md
.claude/rules/api-contracts.md
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
.claude/commands/angular-component.md
.claude/commands/angular-service.md
.claude/commands/angular-test.md
.claude/commands/api-contract.md
```

> **CI/CD**: every project keeps its own pipeline. The rules in `.claude/rules/12-quality-gates.md` state what must be green at the quality stage — wire those checks into your existing CI.
> Copy the relevant snippets into your `.gitlab-ci.yml`.

### Phase 4 — Adapt to project specifics

Fill in within the deployed files:
- Backend: Java version, Spring Boot version, build tool (Gradle/Maven) — note that Flyway 10+ splits the PostgreSQL support into a separate `flyway-database-postgresql` artifact, while Flyway 9 ships it in the single core artifact
- Frontend: Angular, TypeScript, Node versions; zoneless or zone.js; test runner (Karma vs Jest); UI lib (Material, PrimeNG, Tailwind...)
- Integration: springdoc configuration, generated-client path for frontend types

Record the versions **as found**: legacy stacks are documented as-is — never force an upgrade. Modern recommendations (Java 25 LTS or 21, Spring Boot 4.1.x or 3.5.x, Angular 20+ zoneless) apply only when the project is greenfield.

### Phase 5 — Announce completion

```
✅ SDD Framework Java/Spring Boot+Angular installed.

Backend: Java [version] / Spring Boot [version]
Frontend: Angular [version]

SDD agents deployed:
  spec-writer · plan-architect · task-decomposer
  test-generator · code-reviewer

Next steps:
- Create your domain-specific skills in .claude/skills/ if needed
- Start a feature: /sdd-start <FEATURE-ID>-<description>
```

## Critical rules

- **Never modify the source code** of the project. Only `.claude/` is touched.
- **Always wait for validation** before deploying.
- **Use `reference/` files as source of truth**.
- **Adapt content** to project specifics from Phase 1 findings.
- **Migration-guard** is brownfield-only.

## What this skill does NOT do

- Does not create project-specific skills (those go in `.claude/skills/`)
- Does not configure CI/CD
- Does not install Spring Boot starters or NPM packages
- Does not write production code
- Does not generate the OpenAPI contract itself (that's the job of `/api-contract`)
