---
name: sdd-angular-node
description: Generates a Spec-Driven Development framework for a full-stack project combining Angular frontend AND Node.js/Express (or Fastify, NestJS) backend. Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project where the frontend uses Angular (package.json has @angular/core) AND the backend uses Node.js (package.json has express, fastify, or @nestjs/core) WITHOUT a PHP/Symfony backend. Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "create SDD framework", as well as "génère le framework SDD", "installe SDD" when applied to an Angular+Node.js full-stack project. Detects brownfield/greenfield. Provides fine-grained auxiliary commands for both frontend (angular-component, angular-service, angular-test) and backend (node-endpoint, node-service, node-test) plus contract-check for API sync and api-design for OpenAPI generation.
license: Proprietary
---

# SDD Framework — Angular + Node.js Full-Stack

This skill installs a complete SDD framework into a full-stack Angular + Node.js/Express project by deploying the files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The project has an Angular frontend (`package.json` contains `@angular/core`)
- The backend is Node.js/Express, Fastify, or NestJS (`package.json` contains `express`, `fastify`, or `@nestjs/core`)
- There is NO PHP/Symfony backend (`composer.json` absent or without `symfony/framework-bundle`)

Do NOT use when:
- Backend is Symfony → use `sdd-symfony-angular` instead
- Frontend is React/Vue → no dedicated skill (use the core alone)
- Backend is pure PHP → use `sdd-php-backend` instead

## Complete decision tree

```
package.json has @angular/core?
├── YES:
│   └── composer.json has symfony/framework-bundle?
│       ├── YES  → sdd-symfony-angular
│       └── NO:
│           └── package.json has express / fastify / @nestjs/core?
│               ├── YES  → sdd-angular-node  ← THIS SKILL
│               └── NO   → core alone (frontend-only stack)
└── NO:
    └── composer.json has symfony/framework-bundle?
        ├── YES  → sdd-php-symfony
        └── NO:
            └── Any .php files present?
                ├── YES  → sdd-php-backend
                └── NO   → no applicable SDD skill
```

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: minimal code, no `node_modules/`
- **Brownfield**: existing project with code and dependencies in place

Announce:

```
Detected mode  : [GREENFIELD / BROWNFIELD]
Frontend       : Angular [version]
Backend        : [Express x.x / Fastify x.x / NestJS x.x]
ORM/DB         : [Prisma / TypeORM / Mongoose / Drizzle / raw SQL / none]
Structure      : [Nx monorepo / Turborepo / separate repos / flat]
Auth           : [JWT / Passport / OAuth2 / none]
Reason         : [observations]
```

### Phase 1 — Discovery (brownfield)

#### 1.1 — Angular frontend

```
@angular/core         : x.x.x
typescript            : x.x.x
rxjs                  : x.x.x
state-management      : [NgRx / Signal Store / pure RxJS / Signals]
ui-library            : [Angular Material / PrimeNG / custom / none]
tests                 : [Karma+Jasmine / Jest] + [Playwright / Cypress]
```

- Standalone components or NgModules?
- Signals or classic RxJS?
- Centralized `*ApiService` services or scattered HTTP calls?

#### 1.2 — Node.js backend

```
node                  : x.x.x
framework             : [Express x.x / Fastify x.x / NestJS x.x]
typescript            : [enabled / no]
orm                   : [Prisma / TypeORM / Mongoose / Drizzle / raw SQL]
database              : [PostgreSQL / MySQL / MongoDB / SQLite]
auth                  : [JWT / Passport / sessions]
validation            : [Zod / Joi / express-validator / class-validator]
tests                 : [Jest + Supertest / Vitest / Mocha]
```

#### 1.3 — Angular ↔ Node.js integration

- Shared types: present in `packages/shared/` or duplicated?
- OpenAPI/Swagger: generated via `swagger-jsdoc`, `tsoa`, Fastify schema, or absent?
- Error format: uniform across endpoints?
- Frontend/backend drift: `any` types on the Angular side for API responses?

#### 1.4 — Identified gaps

- Endpoints without input validation
- `any` response types on the Angular side
- No uniform error format
- Types duplicated between Angular and the backend
- RxJS subscriptions without unsubscribe

Then ask the 4 clarification questions:
1. Team conventions not visible in the code?
2. Most painful repetitive workflows to automate?
3. Specific constraints (security, architecture)?
4. Retrospective specs for existing features, or new ones only?

For greenfield, ask the setup questions (framework, DB, auth, monorepo, tests, conventions).

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
.claude/rules/angular-conventions.md
.claude/rules/node-conventions.md
.claude/rules/api-contracts.md
.claude/rules/shared-types.md
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
.claude/commands/angular-component.md
.claude/commands/angular-service.md
.claude/commands/angular-test.md
.claude/commands/node-endpoint.md
.claude/commands/node-service.md
.claude/commands/node-test.md
.claude/commands/api-design.md
.claude/commands/contract-check.md
```

> **CI/CD**: GitLab CI templates are available in the toolkit's `core/ci-templates/`.
> Copy the relevant snippets into your `.gitlab-ci.yml`.

### Phase 4 — Adapt to project specifics

Fill in, within the deployed files:
- Angular, Node, TypeScript versions
- Backend framework (Express/Fastify/NestJS)
- ORM and database
- Angular state management
- Test strategies (Karma vs Jest, Playwright vs Cypress)
- Monorepo structure or separate repos

### Phase 5 — Announce completion

```
✅ SDD Framework Angular+Node.js installed.

Frontend : Angular [version]
Backend  : [Express / Fastify / NestJS] [version]

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
- **Adapt content** to project specifics from Phase 1 findings.
- **migration-guard** is brownfield-only.
- **The API contract is defined in spec.md BEFORE implementation** on both sides.
