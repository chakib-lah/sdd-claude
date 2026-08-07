---
name: sdd-php-symfony
description: Generates a Spec-Driven Development framework for a PHP/Symfony backend project (without frontend framework). Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project using PHP + Symfony, Doctrine ORM, and possibly Twig templates - but NOT a separate frontend framework like Angular/React/Vue. Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "génère le framework SDD", "installe SDD" when applied to a project where composer.json contains symfony/framework-bundle. Detects brownfield/greenfield mode. Provides fine-grained auxiliary commands (symfony-entity, symfony-service, symfony-controller, symfony-test). Adds migration-guard for brownfield projects.
license: Proprietary
---

# SDD Framework — PHP / Symfony Backend

This skill installs a complete Spec-Driven Development framework into a PHP/Symfony backend project by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project uses Symfony (`composer.json` contains `symfony/framework-bundle`)
- The project may use Doctrine ORM, Twig, but does NOT have a separate Angular/React/Vue frontend

Do NOT use when:
- The project is pure PHP without framework → use `sdd-php-backend` skill instead
- The project uses Symfony + Angular → use `sdd-symfony-angular` skill instead
- The project uses Laravel → no specific skill yet

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: no `src/`, no `vendor/`, no `composer.lock`
- **Brownfield**: existing code, dependencies installed, architecture in place

Announce in chat:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield)

Analyze and report on:

**Stack detected**
```
symfony/framework-bundle : x.x.x
php                      : x.x.x
doctrine/orm             : x.x.x
doctrine/dbal            : x.x.x
phpunit/phpunit          : x.x.x
other notable bundles    : [list]
```

**Backend architecture**
- Entity structure: directories, naming, Doctrine relations
- Architecture pattern: DDD, standard Symfony, hexagonal, other?
- Services and patterns: Repository, Command Bus, EventDispatcher, Value Objects, DTOs
- Controllers: thin and delegating, or business logic embedded?
- Serialization: normalization groups, response DTOs?

**Existing tests**
- Test directories (`tests/Unit/`, `tests/Functional/`)
- Naming conventions (`*Test.php`)
- DataProviders, fixtures, factories
- Estimated coverage

**CI/CD and tooling**
- `.gitlab-ci.yml`, `Makefile`, `phpstan.neon`, `.php-cs-fixer.php`
- Scripts available in Makefile or composer.json
- PHPStan level

**Gaps and debt**
- Entities without tests
- Services > 200 lines (God classes)
- Missing types in DTOs
- Migrations without `down()`
- Undocumented endpoints

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
.claude/rules/01-constitution.md          (skeleton — never overwrite an existing one)
.claude/rules/02-git-conventions.md
.claude/rules/03-security.md
.claude/rules/10-code-conventions.md
.claude/rules/11-tests-strategy.md
.claude/rules/12-quality-gates.md
.claude/rules/doctrine-conventions.md
.claude/rules/migration-guard.md          (brownfield only)
.claude/sdd/_template/spec.md
.claude/sdd/_template/plan.md
.claude/sdd/_template/tasks.md
.claude/sdd/_template/notes.md
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
```

> **CI/CD**: GitLab CI templates are available in the toolkit's `core/ci-templates/`.
> Copy the relevant snippets into your `.gitlab-ci.yml`.

### Phase 4 — Adapt to project specifics

After copying, fill in:
- `.claude/rules/10-code-conventions.md`: PHP version, Symfony version, architecture detected
- `.claude/rules/11-tests-strategy.md`: PHPUnit version, test categories present
- `.claude/rules/12-quality-gates.md`: target PHPStan level, CS-fixer config, Rector
- `.claude/rules/doctrine-conventions.md`: Doctrine version, ORM patterns

### Phase 5 — Announce completion

```
✅ SDD Framework PHP/Symfony installed.

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
- **Migration-guard** is brownfield-only.

## What this skill does NOT do

- Does not create project-specific skills (those go in `.claude/skills/`)
- Does not configure CI/CD
- Does not install Symfony bundles or Composer dependencies
- Does not write production code
