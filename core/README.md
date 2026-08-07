# core/ — Source of Layer 1 (methodology)

> **Internal source** directory of the SDD Claude. It is not a separate repo nor an installable deliverable: it is the reference location for the framework's universal files.
> **What actually gets installed on a project are the skills** (`skills/sdd-<stack>/`), via `install.sh` / `install.ps1`. `core/` is the source from which these skills are built.

---

## Role of `core/`

`core/` contains the **30 "masters"**: the Layer 1 (methodology) files, identical for all stacks. Each skill embeds a **byte-identical copy** of these 30 masters in its `reference/` directory. The consistency of these copies is verified by hash in `scripts/audit.sh` (section 6).

The 30 masters:

| Category | Count | Files |
|---|---|---|
| Commands | **17** | the 17 universal SDD commands (see table below) |
| Agents | **4** | `spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer` |
| Templates | **5** | `spec.md`, `plan.md`, `tasks.md`, `notes.md`, `sdd-readme.md` |
| Rules | **4** | `00-sdd-framework.md`, `05-constitution.md`, `20-git-conventions.md`, `50-security.md` |

> **Exception: `agents/test-generator.md` is NOT a master.** It is **adapted per skill** (each stack cites only its own test commands). It is therefore excluded from the hash equality check. `core/agents/` nevertheless contains a generic source version of `test-generator.md` as a starting point.

---

## The methodology in brief

### The 4 SDD phases

```
Phase 1 — Specify   →  spec.md (acceptance criteria, design)
Phase 2 — Plan      →  plan.md (order, files, risks)
Phase 3 — Tasks     →  breakdown into atomic T001, T002...
Phase 4 — Implement →  one task, one local commit, green tests; one phase, one branch commit
```

### The 2 verification gates

```
Verify  →  Technical gate: tests + quality + clean branch
Review  →  Functional gate: acceptance criteria coverage
```

### Absolute rule

> **No production code is written before a spec has been validated with `status: approved`.**

---

## 3-layer architecture

```
┌────────────────────────────────────────────────────────────┐
│ LAYER 1 — METHODOLOGY (the 30 masters, source here)        │
│ Universal, identical across all projects                   │
└────────────────────────────────────────────────────────────┘
                            ▼ plugged in per stack
┌────────────────────────────────────────────────────────────┐
│ LAYER 2 — TECHNOLOGY (stack conventions)                   │
│ code/tests/quality rules + scaffolding commands            │
└────────────────────────────────────────────────────────────┘
                            ▼ adapted per project
┌────────────────────────────────────────────────────────────┐
│ LAYER 3 — PROJECT (house conventions, business skills)     │
└────────────────────────────────────────────────────────────┘
```

A **skill** (`skills/sdd-<stack>/`) is the packaging that brings together Layer 1 (the 30 copied masters) **and** Layer 2 (the stack-specific conventions and commands). It is the unit installed on a project. Layer 3 is added manually by the team as the project evolves.

---

## Structure of `core/`

```
core/
├── README.md                  ← This file
├── extension-guide.md         ← Notes on creating a new stack
├── rules/                     ← 3 universal rules (masters)
│   ├── 00-sdd-framework.md    ← The methodology in detail
│   ├── 20-git-conventions.md  ← Universal Git conventions
│   └── 50-security.md         ← Secure-coding baseline + security gate
├── commands/                  ← 17 universal SDD commands (masters)
│   └── …
├── agents/                    ← 5 SDD agents (4 masters + test-generator adapted/skill)
│   ├── spec-writer.md
│   ├── plan-architect.md
│   ├── task-decomposer.md
│   ├── code-reviewer.md
│   └── test-generator.md      ← generic source, then adapted per skill
├── templates/                 ← 5 artifact templates (masters)
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   ├── notes.md
│   └── sdd-readme.md
├── ci-templates/              ← reusable CI snippets
└── examples/
    └── skill-template.md      ← Step-by-step guide to create a new stack skill
```

---

## The 17 universal commands

| Command | Phase | Role |
|---|---|---|
| `/sdd-start` | Init | Creates the branch + the feature directory |
| `/sdd-spec` | 1 — Specify | Interview → generates `spec.md` |
| `/sdd-clarify` | 1 — Specify | Dedicated ambiguity-resolution pass on the spec |
| `/sdd-spec-check` | 1 — Specify | Spec quality checklist before validation |
| `/sdd-plan` | 2 — Plan | Generates `plan.md` from an approved spec |
| `/sdd-tasks` | 3 — Tasks | Breaks down into atomic tasks `T001…TN` |
| `/sdd-implement` | 4 — Implement | Executes ONE task (code + tests + local commit); squashes each phase into one commit |
| `/sdd-verify` | Technical gate | Checks tests, quality, completeness |
| `/sdd-review` | Functional gate | Checks acceptance criteria coverage |
| `/sdd-mr` | Closure | Prepares the Merge Request body |
| `/sdd-archive` | Closure | Files the artifacts into `_archive/` |
| `/sdd-status` | Tracking | Lists features in progress |
| `/sdd-hotfix` | Emergency | Lightened workflow for a Production fix |
| `/sdd-upgrade` | Maintenance | Updates Layer 1 without touching Layers 2/3 |
| `/sdd-changelog` | Release | Generates the CHANGELOG from archived specs |
| `/sdd-revert` | Rollback | Un-ships a feature/phase via the tracked phase commit SHAs |
| `/retro-spec` | Brownfield | Rebuilds a spec from existing code |

**These 17 names and their roles are stable**: do not rename them in a skill's Layer 2, otherwise team portability across projects is broken.

---

## Evolving the framework

### Modifying a master (Layer 1)

1. Modify the file in `core/` (the source).
2. **Propagate the copy verbatim** to the 4 skills (`skills/sdd-*/reference/…`).
3. Run `bash scripts/audit.sh` — section 6 must stay green (byte-identical copies).

> Never edit a master copy directly in a skill: the source is `core/`, and any divergence is detected by the audit.

### Creating a new stack skill

Follow the step-by-step skeleton: **`examples/skill-template.md`**. In short: create `skills/sdd-<stack>/reference/{agents,commands,rules,templates}/`, copy the 30 masters from `core/`, write Layer 2 (conventions + scaffolding commands), adapt `test-generator.md`, write the `SKILL.md`, wire the skill into `install.sh` / `install.ps1` / `skills/README.md`, then validate with `bash scripts/audit.sh`.

---

## Design principles

### Strictly stack-agnostic (Layer 1)

No technology name (PHP, Angular, Doctrine…) appears in the masters. Anything technology-dependent is delegated to the skill's Layer 2.

### Referencing by convention

The universal commands **do not know** the project's tools (`make`, `npm`, `gradle`…). They read this information from the Layer 2 rules under `.claude/rules/`:

- `.claude/rules/30-tests-strategy.md` → test commands to run
- `.claude/rules/40-quality-gates.md` → quality gates to run
- `.claude/rules/20-git-conventions.md` → commit format

### Agent auto-delegation

Commands never hardcode an agent's name. It is the agents that declare, in their `description`, the command that activates them — Claude Code delegates on this basis. Commands thus remain 100% agnostic and identical across skills.

### Discipline > flexibility

- `/sdd-plan` refuses if `spec.md` is not `status: approved`
- `/sdd-implement` refuses to process several tasks in one invocation
- `/sdd-implement` refuses `git commit --no-verify`

---

## Versioning

The toolkit follows SemVer (see `VERSION` and `CHANGELOG.md` at the root):

- **Major**: methodology change (new phase, gate removal…)
- **Minor**: non-breaking command addition, new optional template field
- **Patch**: documentation fixes, clarifications
