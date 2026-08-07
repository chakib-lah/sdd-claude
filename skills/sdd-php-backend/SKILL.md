---
name: sdd-php-backend
description: Generates a Spec-Driven Development framework for a PHP backend project WITHOUT a framework (Symfony, Laravel, etc.). Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project that is pure PHP, legacy PHP, procedural PHP, OOP PHP without framework, PHP scripts, home-grown APIs, or PHP migration projects. Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "create SDD framework", "génère le framework SDD", "installe SDD" when applied to a PHP-only project (no Symfony, no Laravel detected). Detects brownfield/greenfield mode and adapts. Adds refactoring-guard and legacy-rules for brownfield migrations.
license: Proprietary
---

# SDD Framework — Pure PHP Backend

This skill installs a complete Spec-Driven Development framework into a PHP project (without framework) by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project is pure PHP (no Symfony, no Laravel, no major framework detected)
- The project might be legacy procedural, OOP without framework, scripts, or in-progress migration

Do NOT use when:
- The project uses Symfony → use `sdd-php-symfony` skill instead
- The project uses Symfony + Angular → use `sdd-symfony-angular` skill instead
- The project uses Laravel, Slim, Phalcon, or another PHP framework → no specific skill yet, fall back to manual setup

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: no `index.php`, no `src/`, no significant PHP files, no `vendor/`
- **Brownfield**: existing PHP code, possibly without Composer/autoloader

Detect estimated project type:
- Legacy procedural (scripts, includes, globals)
- OOP without framework (classes, possibly with namespaces)
- In-progress migration (partially modernized)

Announce in chat:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Estimated type: [legacy procedural / OOP without framework / in-progress migration]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield only)

Analyze and report on:

**Stack and environment**
- PHP version (from `phpinfo`, `.php-version`, or deduction from syntax)
- Composer presence (`composer.json`)
- Autoloader pattern (PSR-4, PSR-0, manual require, none)
- Database access (PDO direct, MySQLi, custom wrapper, custom ORM)

**Architecture**
- Entry point (`index.php`, custom routing, htaccess rewrite)
- Code organization (procedural, classes without namespace, namespaced OOP)
- Error handling
- Sessions / Auth

**Technical debt**
- Files > 500 lines (God files)
- Free-standing functions count estimate
- Inline SQL in business logic
- Test presence (PHPUnit, manual tests, none)
- Debug leftovers (`var_dump`, `die`, etc.)

**Conventions observed**
- File naming (CamelCase, snake_case, mixed)
- Function/method naming
- Namespaces if any

Then ask the user the 5 brownfield clarification questions:
1. Solo or team maintained?
2. Goal to introduce Composer + PSR-4 if not yet?
3. Critical modules NOT to break?
4. Tolerance for breaking changes?
5. Existing documentation to integrate?

For greenfield, ask the 11 greenfield questions about architecture, conventions, environment.

### Phase 2 — Propose structure

Display the structure that will be deployed, with 2-3 line descriptions, and **wait for validation** before generating.

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
.claude/rules/10-code-conventions.md
.claude/rules/02-git-conventions.md
.claude/rules/11-tests-strategy.md
.claude/rules/12-quality-gates.md
.claude/rules/refactoring-guard.md        (brownfield only)
.claude/rules/legacy-rules.md             (brownfield only)
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
.claude/commands/php-class.md
.claude/commands/php-test.md
.claude/commands/extract-class.md         (brownfield only)
```

> **CI/CD**: GitLab CI templates are available in the toolkit's `core/ci-templates/`.
> Copy the relevant snippets into your `.gitlab-ci.yml`.

### Phase 4 — Adapt to project specifics

After copying, adapt these files to the project's specifics gathered during Phase 1:
- `.claude/rules/10-code-conventions.md`: fill in PHP version, autoloader type, naming conventions detected
- `.claude/rules/11-tests-strategy.md`: indicate if PHPUnit is set up or to be introduced
- `.claude/rules/12-quality-gates.md`: soft for legacy projects, strict for modernized ones

### Phase 5 — Announce completion

```
✅ SDD Framework installed.

Layers deployed:
- Layer 1 (SDD methodology)    : ✅
- Layer 2 (pure PHP stack)     : ✅
- Layer 3 (project skills)     : to be completed in .claude/skills/

SDD agents deployed:
  spec-writer · plan-architect · task-decomposer
  test-generator · code-reviewer

Next steps:
- Create your domain skills in .claude/skills/ if needed
- Start a feature: /sdd-start <FEATURE-ID>-<description>
```

## Critical rules

- **Never modify the source code of the project during this skill execution**. Only `.claude/` is touched.
- **Always wait for validation** before deploying.
- **Brownfield-only files** (`refactoring-guard.md`, `legacy-rules.md`, `extract-class.md`) are skipped in greenfield mode.
- **Use the `reference/` files as source of truth**. Do not rewrite them from memory.
- **Adapt content to project specifics** (versions, conventions detected), do not blindly copy.

## What this skill does NOT do

- Does not create project skills (those are project-specific, the user adds them in `.claude/skills/`)
- Does not configure CI/CD pipelines
- Does not install Composer dependencies
- Does not write production code
