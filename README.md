# SDD Claude — Spec-Driven Development for Claude Code

> **Spec-Driven Development** packaged for Claude Code: a single install deploys commands, agents, rules and templates onto any project.
> For any team that wants to turn a ticket into shipped code in a disciplined, reproducible way, whatever the stack.
> **Golden rule: no production code is written before a spec has been approved (`status: approved`).**

> **Language** — The framework is English-first, but all skills and agents also respond to French trigger phrases, and Claude adapts its interactive output to the user's language.

---

## 3-layer architecture

The framework stacks three layers: the methodology is universal, the technology is plugged in per stack, and the project adds its own specifics.

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 1 — Methodology (universal, identical everywhere)         │
│  15 SDD commands · 5 SDD agents · templates · process rules      │
└────────────────────────────────────────────────────────────────┘
                          ↓ plugged in per stack
┌────────────────────────────────────────────────────────────────┐
│  Layer 2 — Technology (one skill per stack)                      │
│  Code rules · tests · quality gates · scaffolding commands       │
└────────────────────────────────────────────────────────────────┘
                          ↓ adapted per project
┌────────────────────────────────────────────────────────────────┐
│  Layer 3 — Project (added manually by the team)                  │
│  House conventions · domain skills · project templates           │
└────────────────────────────────────────────────────────────────┘
```

- **Layer 1** never changes from one project to another: that is the portability guarantee — a dev who masters one project can switch to another without relearning anything at the process level.
- **Layer 2** brings the conventions and scaffolding specific to the stack.
- **Layer 3** is filled in by the team over the life of the project (house rules, real examples).

---

## The 4 skills

Only one skill activates per project, based on the detected stack:

```
package.json contains @angular/core ?
├── YES
│   ├── Symfony backend (composer.json → symfony/framework-bundle) ? → sdd-symfony-angular
│   └── Node backend (express / fastify / @nestjs) ?                 → sdd-angular-node
└── NO
    ├── composer.json → symfony/framework-bundle ?                   → sdd-php-symfony
    └── PHP without a framework (legacy, scripts, OOP) ?             → sdd-php-backend
```

| Skill | Stack | Typical projects |
|---|---|---|
| `sdd-php-backend` | Pure PHP (no framework) | Legacy, PHP scripts & tools |
| `sdd-php-symfony` | PHP + Symfony + Doctrine | Back office, business API |
| `sdd-symfony-angular` | Symfony + Angular | Full-stack application |
| `sdd-angular-node` | Angular + Node.js/Express | Full-stack application (Node) |

Each skill ships the **15 universal commands** + the **5 SDD agents** + its **stack rules** + its own **scaffolding commands** (e.g. `symfony-entity`, `angular-component`, `node-endpoint`). Details in `skills/README.md`.

---

## Ticket → MR workflow

This is the heart of the framework: a sequence of 15 commands across 4 phases, **paced by manual stop points (✋)**. At each ✋, a human — not the AI — moves the document to `status: approved`. As long as the spec is not `approved`, no production code is written. As long as the plan is not `approved`, no tasks are broken down. **These manual validations are the core of the method.**

```
/sdd-start <PROJ-xxx>-<desc>   → creates the Git branch + the feature folder
                                  (e.g. /sdd-start PROJ-101-user-search)

──────────────── Phase 1 · Specification ────────────────
/sdd-spec                      → guided interview → generates spec.md (status: draft)
/sdd-spec-check                → spec quality checklist before validation
   ✋ MANUAL GATE — a human moves spec.md to status: approved
                    (objective, scope, unambiguous acceptance criteria)

──────────────── Phase 2 · Planning ─────────────────────
/sdd-plan                      → plan.md: approach, order, dependencies, risks
                                  (requires spec.md approved)
   ✋ MANUAL GATE — a human moves plan.md to status: approved

──────────────── Phase 3 · Breakdown ────────────────────
/sdd-tasks                     → breaks down into atomic tasks T001…TN (+ blocked-by)
                                  (requires plan.md approved)
   ✋ MANUAL GATE — a human moves tasks.md to status: approved

──────────────── Phase 4 · Implementation ───────────────
/sdd-implement                 → loop: one task = one commit (T001, then T002…)
/sdd-verify                    → 🚦 TECHNICAL GATE: tests + quality gates + security gate green
/sdd-review                    → 🚦 FUNCTIONAL GATE: every acceptance criterion covered

──────────────── Closure ────────────────────────────────
/sdd-mr                        → prepares the Merge Request body
   → after merge: the feature moves to status: implemented
/sdd-archive                   → files the artifacts (spec/plan/tasks) into _archive/
```

The **3 ✋ MANUAL GATES** (spec → plan → tasks) guarantee that we never build on unvalidated foundations. The **2 🚦 automatic GATES** (`/sdd-verify`, `/sdd-review`) guarantee that we never propose an MR with red tests or an uncovered acceptance criterion.

### The 15 commands at a glance

| Command | Phase | Role |
|---|---|---|
| `/sdd-start` | Init | Creates the branch + the feature folder |
| `/sdd-spec` | 1 | Interview → `spec.md` via `@spec-writer` |
| `/sdd-spec-check` | 1 | Quality checklist before validation |
| `/sdd-plan` | 2 | `spec.md` approved → `plan.md` via `@plan-architect` |
| `/sdd-tasks` | 3 | `plan.md` approved → `tasks.md` via `@task-decomposer` |
| `/sdd-implement` | 4 | One task → one commit (+ `[P]` subagents) |
| `/sdd-verify` | Gate | Tests + quality gates + security gate (technical) |
| `/sdd-review` | Gate | Acceptance criteria coverage via `@code-reviewer` |
| `/sdd-mr` | Closure | Generated Merge Request body |
| `/sdd-archive` | Closure | Artifacts → `_archive/` post-merge |
| `/sdd-status` | Tracking | Dashboard of features in progress |
| `/sdd-hotfix` | Emergency | Lightweight workflow for a Production fix |
| `/sdd-upgrade` | Maintenance | Updates Layer 1 without touching Layers 2/3 |
| `/sdd-changelog` | Release | CHANGELOG from archived specs |
| `/retro-spec` | Brownfield | Rebuilds a spec from existing code |

> The `PROJ-xxx` identifiers and the `User` / `Order` / `Certificate` names are only neutral examples: replace them with your own tickets and entities.

---

## Security by default

Security is built into the method, not bolted on (see `core/rules/50-security.md`, deployed with every skill):

- **Spec phase** — every spec has a **Security considerations** section (data sensitivity, authorization impact, abuse cases); security acceptance criteria are tagged `[SEC]`.
- **Implementation** — baseline rules always apply: server-side input validation, parameterized queries, contextual output encoding, no secrets in code, explicit access control on every endpoint.
- **Verify phase** — `/sdd-verify` runs a **security gate**: dependency audit (`composer audit` / `npm audit`), secret scan on the diff, `[SEC]` task completion, and no debug leftovers. A hotfix does not skip this gate.
- **Review phase** — `@code-reviewer` treats any unmitigated risk as a blocking finding, and the `security-reviewer` global agent covers deeper OWASP audits on demand.

---

## Installation

Installation is a single command (symlink of the skills + copy of the global agents), on Linux/macOS/WSL2 or Windows.

➡️ **See [`INSTALL.md`](INSTALL.md)** for the detailed procedure, verification and updates.

---

## The agents

### 5 SDD agents (built into each skill, deployed into `.claude/agents/`)

| Agent | Role | Invoked by |
|---|---|---|
| `spec-writer` | Writes and validates `spec.md` (unambiguous acceptance criteria) | `/sdd-spec` |
| `plan-architect` | Generates `plan.md` (order, dependencies, risks) | `/sdd-plan` |
| `task-decomposer` | Breaks the plan down into atomic tasks with `blocked-by` | `/sdd-tasks` |
| `test-generator` | Generates tests from the acceptance criteria | `*-test` commands |
| `code-reviewer` | Checks AC coverage and anti-patterns | `/sdd-review` |

### 8 global expert agents (installed once into `~/.claude/agents/`)

| Agent | When to invoke it |
|---|---|
| `debugger` | Stack trace, unexplained behavior |
| `git-assistant` | Commits, conflicts, rebase, MR message |
| `security-reviewer` | OWASP audit before deployment |
| `refactoring-advisor` | God class, code to restructure |
| `symfony-expert` | Symfony, modern PHP, Doctrine |
| `angular-expert` | Angular, Signals, RxJS |
| `doctrine-migration-expert` | Complex migrations, SQL views |
| `phpstan-fixer` | PHPStan static analysis errors |

---

## The guardrail: `scripts/audit.sh`

Run it after **any change** to the toolkit (adding a command/agent/rule, editing a shared file):

```bash
bash scripts/audit.sh
```

In a single pass it checks: the **structure** of the skills, **completeness** (15 commands + 5 agents per skill, 8 global agents), the absence of **ghost references**, the consistency of **agent delegations**, the **docs**, and the **absence of divergent duplication** (files shared across skills must stay byte-identical). Output is `✅ AUDIT OK` or the list of detected problems.

---

## Extending the framework: adding a stack

The toolkit is not limited to the 4 shipped skills: you can add a skill for a new stack (Java/Spring, Python/Django, Go…) by copying Layer 1 verbatim and writing only Layer 2 (code rules, tests, quality gates, scaffolding).

➡️ **See [`core/extension-guide.md`](core/extension-guide.md)** for the full walkthrough (anatomy, anti-drift discipline, checklist and validation via `scripts/audit.sh`).

---

## See also

| File | Contents |
|---|---|
| `INSTALL.md` | Detailed installation guide |
| `skills/README.md` | Skills decision tree |
| `core/extension-guide.md` | Creating a new stack skill |
| `core/ci-templates/` | CI snippets |

Version 1.0.0 — July 2026.
