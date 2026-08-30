---
name: sdd-symfony-angular
description: Generates a Spec-Driven Development framework for a full-stack project combining PHP/Symfony backend AND Angular frontend. Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project where the backend uses Symfony (composer.json has symfony/framework-bundle) AND the frontend uses Angular (package.json has @angular/core). Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "génère le framework SDD", "installe SDD" when applied to a Symfony+Angular full-stack project. Detects brownfield/greenfield. Provides fine-grained auxiliary commands for both backend (symfony-entity, symfony-service, symfony-controller, symfony-test) and frontend (angular-component, angular-service, angular-test) plus api-contract for OpenAPI sync. Adds migration-guard for brownfield.
license: MIT
---

# SDD Framework — Symfony + Angular Full-Stack

This skill installs a complete Spec-Driven Development framework into a full-stack Symfony + Angular project by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project uses Symfony backend (`composer.json` contains `symfony/framework-bundle`)
- The project uses Angular frontend (`package.json` contains `@angular/core`)
- The two roots are **discovered** (where `composer.json` and `angular.json` live) — real projects name them freely, not necessarily `backend/`/`frontend/`

Do NOT use when:
- Backend is Symfony but no Angular → use `sdd-php-symfony` instead
- Frontend is React/Vue (not Angular) → no specific skill yet
- Backend is pure PHP without Symfony → use `sdd-php-backend` instead

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: minimal code, no `vendor/`, no `node_modules/`
- **Brownfield**: existing backend + frontend in place

Announce:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Backend: Symfony [version] [+ notable bundles]
Frontend: Angular [version] [+ notable libs]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield)

#### 1.1 — Symfony backend

```
symfony/framework-bundle : x.x.x
php                      : x.x.x
doctrine/orm             : x.x.x
doctrine/dbal            : x.x.x
phpunit/phpunit          : x.x.x
other notable bundles    : [list]
```

- Entity structure, naming, Doctrine relations
- Architecture pattern (DDD, standard, hexagonal)
- Services and patterns
- Existing tests
- Configuration

#### 1.2 — Angular frontend

```
angular/core/version     : x.x.x
node/version             : x.x.x (from package.json engines or .nvmrc)
typescript/version       : x.x.x
style/ui-lib             : [Material / PrimeNG / Tailwind / custom / none]
state management         : [NgRx / Signal Store / plain RxJS / other]
```

- Backend/frontend roots (where `composer.json` and `angular.json` actually live)
- Standalone components or NgModules?
- Signals (Angular 17+) or classic RxJS?
- ZoneJS or zoneless?
- Test runner: Vitest, Karma+Jasmine, Jest? (`angular.json` test builder)
- Lint: ESLint/angular-eslint, TSLint, or absent?
- TypeScript `strict` / Angular `strictTemplates` enabled?
- Formatter configured (Prettier, other, none)?
- Selector prefix (`angular.json` → `prefix`)
- E2E: Cypress, Playwright, other?

#### 1.3 — Symfony ↔ Angular integration

- API contracts: which OpenAPI provider owns the contract — `nelmio/api-doc-bundle`, `api-platform`, other, none?
- Automated Angular type/client generation: generator dependency and script (`package.json`), contract location, output directory?
- Auth: `lexik/jwt-authentication-bundle`, session, other?
- CORS: `nelmio/cors-bundle`, other?
- Serialization: `symfony/serializer` + groups, JMS, `api-platform`, other?

#### 1.4 — Identified gaps

- Endpoints without TypeScript types on the Angular side
- Entities without tests
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
.claude/rules/doctrine-conventions.md
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
.claude/commands/symfony-entity.md
.claude/commands/symfony-service.md
.claude/commands/symfony-controller.md
.claude/commands/symfony-test.md
.claude/commands/angular-component.md
.claude/commands/angular-service.md
.claude/commands/angular-test.md
.claude/commands/api-contract.md
```

> **CI/CD**: every project keeps its own pipeline. The rules in `.claude/rules/12-quality-gates.md` state what must be green at the quality stage — wire those checks into your existing CI.

### Phase 4 — Dispose of the detected project facts (Layer 2 stays untouched)

The Layer-2 files just deployed are **skill-owned**: immediately after installation the project's Layer 2 is **byte-identical to `reference/`**, and it stays that way — never edit a deployed Layer-2 rule with project findings. Instead, dispose of every Phase 1 finding by ownership:

- **Discoverable on demand — do not persist**: backend/frontend roots; PHP, Symfony, Doctrine, Angular, Node and TypeScript versions (`composer.json`/`composer.lock`, `package.json`/lockfile); UI library and state-management packages (`package.json`); test runner, lint setup, strictness, formatter and selector prefix (`angular.json`, `tsconfig*.json`, `package.json`); OpenAPI provider and generator (`composer.json`, `package.json` scripts). Commands read these canonical sources when they need them.
- **Durable project context → Layer 3**: the detected backend architecture (DDD or standard) and frontend structure observations no manifest records — `.claude/rules/project-architecture.md`.
- **Project policies → Layer 3**: team decisions on state management (e.g. signals-first) or migration sequencing (e.g. a Karma/Jasmine → Vitest migration plan) — `.claude/rules/project-architecture.md` / `.claude/rules/project-testing.md`.
- **Diagnostic only**: the Phase 1 stack report is announced in the chat and not persisted.

Create a Layer-3 file **only if at least one durable fact or policy needs that subject**; when an existing project rule already owns the subject, reuse it — never create empty or placeholder project files, and never create a second owner for the same subject.

### Phase 5 — Announce completion

```
✅ SDD Framework Symfony+Angular installed.

Backend: Symfony [version]
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
- Does not install Symfony bundles or NPM packages
- Does not write production code
- Does not generate the OpenAPI contract itself (that's the job of `/api-contract`)
