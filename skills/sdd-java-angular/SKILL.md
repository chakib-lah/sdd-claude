---
name: sdd-java-angular
description: Generates a Spec-Driven Development framework for a full-stack project combining Java/Spring Boot backend AND Angular frontend. Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project where the backend uses Spring Boot (build.gradle or pom.xml contains org.springframework.boot) AND the frontend uses Angular (package.json has @angular/core). Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "create SDD framework", "génère le framework SDD", "installe SDD" when applied to a Spring Boot + Angular full-stack project. Detects brownfield/greenfield. Provides fine-grained auxiliary commands for both backend (java-entity, java-service, java-controller, java-test) and frontend (angular-component, angular-service, angular-test) plus api-contract for OpenAPI contract sync. Adds migration-guard for brownfield.
license: MIT
---

# SDD Framework — Java/Spring Boot + Angular Full-Stack

This skill installs a complete Spec-Driven Development framework into a full-stack Spring Boot + Angular project by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project uses a Spring Boot backend (`build.gradle` or `pom.xml` contains `org.springframework.boot`)
- The project uses an Angular frontend (`package.json` contains `@angular/core`)
- The two roots are **discovered** (where the Gradle/Maven build and `angular.json` live) — real projects name them freely (`back/`, `server/`, `apps/web/`…), and the backend may even sit at the repository root

Do NOT use when:
- Backend is Spring Boot but no Angular → use `sdd-java-backend` instead
- Frontend is Angular but backend is Node.js → use `sdd-angular-node` instead
- Frontend is Angular but backend is Symfony → use `sdd-symfony-angular` instead
- Backend is Symfony without a frontend framework → use `sdd-php-symfony` instead
- Frontend is React/Vue (not Angular) → no specific skill yet

## Process

### Phase 0 — Detect mode

Inspect the repository and **discover both roots** — where `build.gradle`/`pom.xml` and `angular.json` actually live (never assume `backend/`/`frontend/`; the backend root may be the repository root itself):

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
backend root             : [discovered directory — may be the repo root]
build tool               : Gradle x.x / Maven x.x — wrapper location: [path]
module structure         : [single project / multi-module]
dependency locking       : [enabled + gradle.lockfile / not enabled]
java                     : x
spring-boot              : x.x.x
hibernate                : x.x.x
flyway / liquibase       : x.x.x
mapstruct / lombok       : x.x.x / x.x.x
junit / mockito          : x.x.x / x.x.x
```

- Package structure: layered (`controller/service/repository`) or hexagonal?
- Controllers thin and delegating, or business logic embedded?
- Mapping: MapStruct, manual, or entities exposed directly?
- Test tasks/goals actually defined (`./gradlew tasks`, surefire/failsafe config) and suite convention (`*Test` / `*IT` / `*IntTest` / `*IntegrationTest` / dedicated source sets)?
- Database strategy in tests: Testcontainers, embedded PostgreSQL, CI service?
- Quality tools actually configured: JaCoCo, Sonar, Checkstyle, Spotless, other equivalents?

#### 1.2 — Angular frontend

```
frontend root            : [discovered directory where angular.json lives]
angular/core/version     : x.x.x
node/version             : x.x.x (from package.json engines or .nvmrc)
typescript/version       : x.x.x
style/ui-lib             : [Material / PrimeNG / Tailwind / custom / none]
state management         : [Signals / NgRx / plain RxJS / other]
```

- Standalone components or NgModules?
- zone.js or zoneless change detection?
- Signals (Angular 17+) or classic RxJS?
- Test runner: Vitest, Karma+Jasmine, Jest? (`angular.json` test builder + project scripts)
- Lint: ESLint/angular-eslint, other, or absent — and is it actually enforced (blocking) or configured-but-broken?
- TypeScript `strict` / Angular `strictTemplates` enabled?
- Formatter configured (Prettier, other, none)?
- Selector prefix (`angular.json` → `prefix`)
- E2E: Cypress, Playwright, other?
- Runtime config: `assets/config.json` or `environments/`? `proxy.conf.json` present?

#### 1.3 — Spring Boot ↔ Angular integration

- API contract source mode: which provider owns the contract (springdoc-openapi, another export mechanism), a project-owned hand-written OpenAPI document, or none?
- Provider export mechanism (MODE A): runtime endpoint (URL/path from configuration), build-time export plugin (task name + generated artifact location), or project script? Does the export need a live/startable app?
- Tracked contract snapshot: is a generated OpenAPI file versioned in Git (path), or is the contract a build artifact only? (Both are valid — a project fact.)
- Project-owned contract (MODE B): document path and format (JSON/YAML)?
- Automated Angular type/client generation: generator dependency, package script, contract input, output directory?
- Frontend types today: generated, or hand-written models/services maintained manually?
- Auth: actual mechanism — Spring Security OAuth2/JWT, session, Basic Auth/custom filter, SSO/gateway identity? Authorization convention (`@PreAuthorize`, other)?
- CORS: `CorsConfigurationSource` bean, `@CrossOrigin`, gateway-level?
- Uniform API error format across endpoints?

#### 1.4 — Identified gaps

- No machine-readable contract source at all (no provider, no project-owned document) → PROJECT_TOOLING_GAP
- Valid contract source but no automated frontend type/client generation → API_CONTRACT_AUTOMATION_GAP
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
.claude/rules/01-git-conventions.md
.claude/rules/02-security.md
.claude/rules/03-code-quality.md
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

### Phase 4 — Dispose of the detected project facts (Layer 2 stays untouched)

The Layer-2 files just deployed are **skill-owned**: immediately after installation the project's Layer 2 is **byte-identical to `reference/`**, and it stays that way — never edit a deployed Layer-2 rule with project findings. Instead, dispose of every Phase 1 finding by ownership:

- **Discoverable on demand — do not persist**: backend/frontend roots, backend versions, build tool and wrapper location (`build.gradle`/`pom.xml`), test tasks and quality tools (build configuration), frontend versions, zoneless vs zone.js, test runner, lint/strictness/formatter/selector prefix and UI library (`package.json`, `angular.json`, `tsconfig*.json`, `main.ts`), API contract source/provider and export mechanism (`application.yml`, build files, `package.json` scripts). Commands read these canonical sources when they need them. (Diagnostic aid, already stack knowledge in `jpa-conventions.md`: Flyway 10+ splits PostgreSQL support into `flyway-database-postgresql`; Flyway 9 ships it in core.)
- **Durable project context → Layer 3**: the backend↔frontend integration wiring (generated-client path for frontend types) and architecture observations — `.claude/rules/project-architecture.md`.
- **Project policies → Layer 3**: team decisions on test strategy or state management — `.claude/rules/project-testing.md` / `.claude/rules/project-architecture.md`.
- **Diagnostic only**: the Phase 1 stack report is announced in the chat and not persisted. Report versions **as found** — never force an upgrade; modern recommendations (Java 25 LTS or 21, Spring Boot 4.1.x or 3.5.x, Angular 20+ zoneless) apply only to greenfield scaffolding.

Create a Layer-3 file **only if at least one durable fact or policy needs that subject**; when an existing project rule already owns the subject, reuse it — never create empty or placeholder project files, and never create a second owner for the same subject.

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
- **Never edit a deployed Layer-2 rule with project facts** — Layer 2 stays byte-identical to `reference/` (that is what lets `/sdd-upgrade` keep it in sync with the skill); project truth goes to Layer 3 (Phase 4).
- **Migration-guard** is brownfield-only.

## What this skill does NOT do

- Does not create project-specific skills (those go in `.claude/skills/`)
- Does not configure CI/CD
- Does not install Spring Boot starters or NPM packages
- Does not write production code
- Does not generate the OpenAPI contract itself (that's the job of `/api-contract`)
