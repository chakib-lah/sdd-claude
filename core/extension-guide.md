# Extension guide — Creating a stack skill

> How to add a technology-specific skill (PHP/Symfony, Symfony+Angular, Java/Spring, Python/Django, Go, etc.) that plugs into the toolkit's common methodology core.

---

## Principle

The toolkit stacks **3 layers**:

- **Layer 1 — Universal methodology**: the 17 SDD commands, the 5 SDD agents, the templates and the 4 process rules. Identical everywhere, never adapted.
- **Layer 2 — Technology**: code rules, test strategy, quality gates and scaffolding commands specific to the stack.
- **Layer 3 — Project**: business skills, house conventions, project-specific code templates (added by the team).

A **stack skill** packages Layer 1 **(copied verbatim)** + Layer 2 **(stack-specific)**. Layer 3 is added per project, after installation.

---

## Anatomy of a stack skill

A skill lives in `skills/sdd-<stack>/`. It carries a `SKILL.md` (frontmatter + scope description) and a `reference/` directory whose content is deployed into the project's `.claude/` at installation time.

```
skills/sdd-<stack>/
├── SKILL.md                          ← frontmatter (name, description), scope, triggers
└── reference/
    ├── agents/                       ← 5 SDD agents
    │   ├── spec-writer.md            ← MASTER (copied verbatim from core)
    │   ├── plan-architect.md         ← MASTER
    │   ├── task-decomposer.md        ← MASTER
    │   ├── code-reviewer.md          ← MASTER
    │   └── test-generator.md         ← ONLY agent adapted to the stack
    ├── commands/                     ← 17 SDD commands + scaffolding commands
    │   ├── sdd-start.md … retro-spec.md   ← 17 MASTERS (copied verbatim from core)
    │   └── <stack>-entity.md, <stack>-test.md, …   ← stack-specific (Layer 2)
    ├── rules/
    │   ├── 00-sdd-framework.md       ← MASTER (methodology, copied from core)
    │   ├── 20-git-conventions.md     ← MASTER (Git, copied from core)
    │   ├── 50-security.md            ← MASTER (security baseline, copied from core)
    │   ├── 10-code-conventions.md    ← stack-specific (Layer 2)
    │   ├── 30-tests-strategy.md      ← stack-specific (Layer 2)
    │   ├── 40-quality-gates.md       ← stack-specific (Layer 2)
    │   └── <stack extras>.md         ← e.g. doctrine-conventions, angular-conventions, migration-guard…
    └── templates/                    ← 5 process templates
        └── spec.md, plan.md, tasks.md, notes.md, sdd-readme.md   ← MASTERS (copied from core)
```

> **"MASTER"** = Layer 1 file whose source of truth is `core/`. It is **copied byte for byte**, never rewritten. See the next section.

---

## Consistency with the core (anti-drift)

This is the most important rule in this guide. Team portability relies on Layer 1 being **rigorously identical** in all skills. A dev who masters one project must find exactly the same commands, agents and templates on another one, byte for byte.

### (a) The 30 masters from `core/` are copied verbatim

When creating a skill, we **copy** — without ever adapting them — the **30 master files** from `core/` to `skills/sdd-<stack>/reference/`:

| Origin (`core/`) | Count | Destination (`reference/`) |
|---|---|---|
| `core/commands/*.md` (the 17 SDD commands) | 17 | `commands/` |
| `core/agents/*.md` **except `test-generator.md`** | 4 | `agents/` |
| `core/templates/*.md` | 5 | `templates/` |
| `core/rules/*.md` (`00-sdd-framework`, `05-constitution`, `20-git-conventions`, `50-security`) | 4 | `rules/` |
| **Total** | **30** | |

These 30 files are not to be touched: no renaming, no rephrasing, no "local improvement". Any evolution happens in `core/` and is then **re-propagated** to all skills (see *Synchronization with the core*).

### (b) Only `test-generator` is adapted to the stack

`test-generator.md` is the **only** one of the 5 SDD agents that depends on the technology (it knows PHPUnit, Jest/Karma, JUnit… and the `*-test` commands actually present in the skill). It is therefore the **only agent excluded** from the hash equality check — it is rewritten for the stack. The 4 other agents remain masters.

### (c) What is specific to the skill (Layer 2)

Everything else — and **only** the rest — is stack-specific:

- The Layer 2 rules: `10-code-conventions.md`, `30-tests-strategy.md`, `40-quality-gates.md`, plus possible stack extras (`doctrine-conventions.md`, `angular-conventions.md`, `node-conventions.md`, `api-contracts.md`, `migration-guard.md`, `legacy-rules.md`, `shared-types.md`, …).
- The `<stack>-*` **scaffolding commands** (e.g. `symfony-entity`, `angular-component`, `node-endpoint`).
- The `test-generator` agent (point b).

### (d) Automatic verification: `scripts/audit.sh`

After creating (or modifying) a skill, **always** run:

```bash
bash scripts/audit.sh
```

The audit checks in a single pass:

1. **Structure** — `SKILL.md` present, `reference/{agents,commands,rules,templates}/` non-empty, no `settings.json` (option A: no hooks), skill wired into the installers.
2. **Completeness** — the 17 core commands + the 5 SDD agents present in the skill, the 8 global agents present.
3. **Ghost references** — every cited rule / command (`.claude/rules/X.md`, `.claude/commands/X.md`) actually exists.
4. **Delegations** — `plan-architect` does cite `/sdd-plan`; `test-generator` cites only `*-test` commands actually present in the skill.
5. **Docs** — correct command count (17), skill documented in `skills/README.md`.
6. **Anti-drift (hash equality)** — every `core/` master is **byte-identical** (md5) in the 4 skills, **`test-generator` excepted**; and the groups shared between skills of the same family remain identical (`angular-*` commands/rules between `sdd-symfony-angular` and `sdd-angular-node`; `symfony-*` commands/rules between `sdd-php-symfony` and `sdd-symfony-angular`).

The output must remain `✅ AUDIT OK`. Any drift of a master triggers a `✗ … differs from core/ (drift)`.

---

## Strict rules for stack skills

### ❌ Prohibitions

**Never rename or redefine the 17 universal SDD commands**:
`/sdd-start`, `/sdd-spec`, `/sdd-spec-check`, `/sdd-plan`, `/sdd-tasks`, `/sdd-implement`, `/sdd-verify`, `/sdd-review`, `/sdd-mr`, `/sdd-archive`, `/sdd-status`, `/sdd-hotfix`, `/sdd-upgrade`, `/sdd-changelog`, `/retro-spec`.

These commands belong to Layer 1. Modifying them breaks team portability across projects.

**Never alter a master** (see *Consistency with the core*): the 30 masters are copied verbatim. The only allowed adaptation on the agents side is `test-generator`.

**Never pollute the methodology with tech**:
- No mention of "PHPUnit", "Jest", "JUnit" in `00-sdd-framework.md`.
- No mention of "Symfony", "Angular", "Spring" in the process files.

**Never include business skills** in a stack skill:
- Project-specific skills (e.g. SSO, SOAP, billing) are project-specific, not stack-specific.
- They belong to Layer 3.

### ✅ Permissions

- Freely define the stack's code rules (`10-code-conventions.md`).
- Define the test strategy and execution commands (`30-tests-strategy.md`).
- Define the quality gates (`40-quality-gates.md`) and the stack extras.
- Add auxiliary scaffolding commands (`<stack>-entity`, `<stack>-component`, etc.).
- Adapt `test-generator` to the stack.
- Add stack-specific code templates in `templates/`.

---

## Granularity of auxiliary commands

Scaffolding granularity is a **design choice**. Two families exist; pick one and apply it consistently across the team's skills.

### Option A — Coarse granularity

One command per business layer (scaffold entity + service + controller + tests in one shot). Relevant when you want to generate a vertical slice in one call.

### Option B — Fine granularity

One command per artifact type. **This is the option chosen in all the toolkit's current skills**, because it composes better with the `/sdd-implement` loop (one task → one artifact → one commit):

| Skill | Actual scaffolding commands |
|---|---|
| `sdd-php-symfony` | `/symfony-entity`, `/symfony-service`, `/symfony-controller`, `/symfony-test` |
| `sdd-symfony-angular` | `/symfony-entity`, `/symfony-service`, `/symfony-controller`, `/symfony-test`, `/angular-component`, `/angular-service`, `/angular-test`, `/api-contract` |
| `sdd-angular-node` | `/angular-component`, `/angular-service`, `/angular-test`, `/node-endpoint`, `/node-service`, `/node-test`, `/api-design`, `/contract-check` |
| `sdd-php-backend` | `/php-class`, `/php-test`, `/extract-class` |

> All scaffolding commands are **tools**: they read `spec.md` / `plan.md` to draw from their content, but **never replace** `/sdd-implement`.

---

## `SKILL.md` template

A stack skill's `SKILL.md` must:

1. Declare the scope (when to use it / when not to use it) and the detection triggers (e.g. `composer.json` contains `symfony/framework-bundle`).
2. Describe the deployment from `reference/` to `.claude/`.
3. Detect brownfield / greenfield mode and adapt to it.
4. Check the presence of the 30 masters (otherwise, refuse and point back to the core).

Typical skeleton of the installation flow:

```markdown
# SDD Framework — <Stack>

> <Stack> variant of the SDD toolkit. Deploys reference/ into .claude/.

## Phase 0 — Common core verification
Check the presence of the Layer 1 masters:
- .claude/rules/00-sdd-framework.md, 20-git-conventions.md, 50-security.md
- the 17 commands .claude/commands/sdd-*.md (+ retro-spec.md)
- the templates .claude/sdd/_template/*.md
If any is missing: refuse and install Layer 1 first.

## Phase 1 — <Stack> Discovery
[Stack detection + at most 3 technology-focused questions — no process questions]

## Phase 2 — Proposed structure
[List of Layer 2 files to add — the masters are already in place]

## Phase 3 — Generation
[Sequential generation of the Layer 2 files, one by one]

## End
✅ <Stack> skill installed.
Next step: add the project's business skills in .claude/skills/ (Layer 3).
```

---

## Quality checklist for a stack skill

Before publishing a skill, check:

- [ ] The **30 masters** from `core/` are copied verbatim into `reference/` (verified by `audit.sh §6`)
- [ ] The **17 universal SDD commands** are neither renamed nor redefined
- [ ] Only `test-generator` is adapted to the stack; the 4 other SDD agents remain masters
- [ ] The granularity of the auxiliary commands is consistent with the team's other skills
- [ ] The Layer 2 rules are technical only (no business, no process)
- [ ] The auxiliary commands read `spec.md` / `plan.md` and do not replace `/sdd-implement`
- [ ] No `settings.json` (option A — no hooks)
- [ ] The skill is wired into `install.sh` / `install.ps1` and documented in `skills/README.md`
- [ ] `bash scripts/audit.sh` returns `✅ AUDIT OK`

---

## Example: creating the PHP/Symfony skill

### Discovery (Phase 1)

Focused questions:
1. PHP / Symfony / Doctrine versions?
2. Architecture (DDD, standard Symfony, hexagonal)?
3. Auth bundles (lexik/jwt, symfony/security)?
4. PHPStan level?
5. Quality tools (CS-fixer, Rector)?

### Generation (Phase 3) — Layer 2 only

The 30 masters are already copied from `core/`. Only the stack-specific files are generated:

```
reference/rules/
  10-code-conventions.md       ← PHP 8.x strict_types, PSR-12, Symfony conventions
  30-tests-strategy.md         ← PHPUnit, WebTestCase, fixtures, conventions
  40-quality-gates.md          ← PHPStan level X, CS-fixer, Rector, make quality
  doctrine-conventions.md      ← stack extra
  migration-guard.md           ← brownfield extra

reference/commands/            ← fine granularity (option B)
  symfony-entity.md            ← scaffolds a Doctrine entity + mapping
  symfony-service.md           ← scaffolds an application service
  symfony-controller.md        ← scaffolds a controller + route
  symfony-test.md              ← scaffolds the tests from the spec

reference/agents/
  test-generator.md            ← adapted: PHPUnit, WebTestCase, fixtures
```

### What is NOT in the skill

- Project-specific skills (e.g. SSO, SOAP, billing) → Layer 3 (project)
- Project-specific code templates → project
- Business entity names (e.g. `User`, `Order`) → project
- Connections to specific tools (Jira) → core or project

---

## Existing skills and extension leads

### Already packaged (4 skills)

| Skill | Stack | Typical projects |
|---|---|---|
| `sdd-php-backend` | Pure PHP (no framework) | Legacy, PHP scripts & tools |
| `sdd-php-symfony` | PHP + Symfony + Doctrine | Back-office, business API |
| `sdd-symfony-angular` | Symfony + Angular | Full-stack application |
| `sdd-angular-node` | Angular + Node.js/Express | Full-stack application (Node) |

### Leads for new stacks

1. `sdd-java-spring` — Java / Spring Boot projects
2. `sdd-python-django` — Python / Django projects
3. `sdd-go` — Go services

For each: copy the 30 masters, write Layer 2 (rules + scaffolding + `test-generator`), wire the installers and `skills/README.md`, then validate with `audit.sh`.

---

## Distribution

As the skills mature, several distribution paths are possible:

### Phase 1 — Skills (current state)

Each stack is a skill installed by symlink via `install.sh` / `install.ps1`, which deploys `reference/` into `.claude/`.

### Phase 2 — Repo templates

Create a `cookiecutter` or `degit` per stack that scaffolds the `.claude/` structure directly.

### Phase 3 — Central registry

Distribute the skills via a shared team registry.

### Phase 4 — Claude Code plugin

If a plugin system is available, package the toolkit as an installable plugin.

---

## Synchronization with the core

When a `core/` master evolves (new Layer 1 version):

1. Modify the file in `core/` (single source of truth).
2. **Re-propagate** the master verbatim to the 4 skills (`reference/…`).
3. Run `bash scripts/audit.sh`: section 6 must turn green again (hash equality restored).
4. User projects apply the update via `/sdd-upgrade` (updates Layer 1 without touching Layers 2/3).

As long as the core does not change, the skills remain valid indefinitely. As long as the audit is green, team portability is guaranteed.
