# SDD Framework — Methodology

> **Layer 1 — Universal methodology.**  
> This file is the absolute reference for every agent and every human working on this project.  
> It defines the WHAT and the WHY of SDD. The technical HOW lives in the other `rules/` and in the `commands/`.

---

## Absolute rule

> **No implementation code is written before a spec has been validated with `status: approved`.**

This rule applies to:
- The humans on the team
- Claude Code during interactive sessions
- Subagents spawned during `/sdd-implement`
- Any automation scripts

No exceptions, except for critical Production hotfixes (see `### Production Hotfix`).

---

## The 4 SDD phases

```
┌──────────────────────────────────────────────────────────┐
│  Phase 1 — Specify                                       │
│  Understand the problem and freeze the expected outcome  │
│  Artifact: spec.md                                       │
│  Command: /sdd-spec                                      │
└──────────────────────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 2 — Plan                                          │
│  Decide how we are going to build it                     │
│  Artifact: plan.md                                       │
│  Command: /sdd-plan                                      │
│  Prerequisite: spec.md status: approved                  │
└──────────────────────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 3 — Tasks                                         │
│  Break down into atomic executable units                 │
│  Artifact: tasks.md                                      │
│  Command: /sdd-tasks                                     │
│  Prerequisite: plan.md status: approved                  │
└──────────────────────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 4 — Implement                                     │
│  Execute one task, validate, commit                      │
│  Artifact: code + commits                                │
│  Command: /sdd-implement (one task per invocation)       │
│  Prerequisite: tasks.md status: approved                 │
└──────────────────────────────────────────────────────────┘
                          ▼
                  [All tasks done]
                          ▼
┌──────────────────────────────────────────────────────────┐
│  Verify Gate (technical)                                 │
│  Check: tests, quality gates, completeness               │
│  Command: /sdd-verify                                    │
└──────────────────────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────┐
│  Review Gate (functional)                                │
│  Check: AC coverage by the implementation                │
│  Command: /sdd-review                                    │
└──────────────────────────────────────────────────────────┘
                          ▼
                  [Push + Merge Request]
```

Within Phase 1, two complementary commands support the spec before approval: `/sdd-clarify` (dedicated ambiguity-resolution pass) and `/sdd-spec-check` (scored quality gate).

---

## The status lifecycle

Each artifact (`spec.md`, `plan.md`, `tasks.md`) carries a `status` in its frontmatter:

```yaml
---
feature: <kebab-case-name>
status: draft | in-review | approved | implemented
created: YYYY-MM-DD
author: <name>
---
```

### Meaning

| Status | Meaning | Consequence |
|---|---|---|
| `draft` | Being written | The next phase refuses to start |
| `in-review` | Awaiting review | The next phase refuses to start |
| `approved` | Validated, authorizes the next phase | The next phase may start |
| `implemented` | Implemented (post-merge) | Can be archived |

### Normal lifecycle

```
draft → in-review → approved → implemented
```

**Exception — retrospective specs.** A spec carrying `retrospective: true` (produced by
`/retro-spec`) escapes this lifecycle: it documents code that already exists, so it is created
directly with `status: implemented`, is never "in progress", and can be archived immediately.
`/sdd-plan`, `/sdd-tasks` and `/sdd-implement` do not apply to it.

### The transition to `approved` is manual

This is intentional. Moving to `approved` is the act by which a human takes responsibility for the artifact's content. No agent may do it automatically.

---

## SDD directory structure

```
.claude/sdd/
├── README.md                                  ← static SDD guide (live state: /sdd-status)
├── _template/                                 ← skeletons
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   ├── notes.md
│   ├── jira-story-fr.md / jira-story-en.md    ← retro-spec export trames (per language)
│   └── spec-doc-fr.md / spec-doc-en.md        ← retro-spec export trames (per language)
├── _archive/                                  ← merged features
│   └── <FEATURE-XXX>-<description>/
└── <FEATURE-XXX>-<description>/               ← features in progress
    ├── spec.md
    ├── plan.md
    ├── tasks.md
    ├── notes.md                               ← free-form logbook
    └── exports/                               ← AMOA deliverables (retrospective specs only, optional)
```

### Feature directory naming convention

```
<TICKET-ID>-<short-kebab-case-description>
```

Examples:
- `PROJ-101-user-search`
- `PROJ-102-auth-token-refresh`
- `PROJ-103-export-csv`

The `TICKET-ID` must match **exactly** the ticket in the ticketing tool used by the project.

### Active-feature detection

Every SDD command identifies the active feature **from the current Git branch**. When that heuristic is ambiguous — detached HEAD, a branch matching no feature folder, several matching folders, or a Git worktree on another feature — the command must **not guess**: it lists the folders in `.claude/sdd/` whose artifacts are not yet `implemented` and asks the user to pick one.

---

## The project constitution

Alongside the per-feature artifacts, a project may maintain a **project constitution** (`.claude/rules/project-constitution.md` — **Layer 3, project-owned**): the durable **project** principles that outlive any single feature, numbered `P1…PN` and **ratified by the team** (`status: ratified` — a human act, like every approval in SDD). Universal engineering invariants do not belong there — they are already owned by the universal rules (`00-sdd-framework.md`, `01-git-conventions.md`, `02-security.md`, `03-code-quality.md`); stack-wide truths belong to the Layer-2 rules of the selected skill.

When a project constitution exists:
- while `status: draft`, `/sdd-spec-check` and `/sdd-review` check its principles **informatively — never blocking**;
- once `status: ratified`, `/sdd-spec-check` verifies the spec violates no principle (scored criterion) and `/sdd-review` treats a violation in the diff as a **blocking finding**.

Without a project constitution, these checks are skipped ("no constitution"). No skeleton is deployed: the team creates the file the day it wants one, and `/sdd-upgrade` migrates a legacy `01-constitution.md` into it, preserving content and ratification metadata.

---

## Working language

Project-facing SDD communication — `spec.md`, `plan.md`, `tasks.md`, `notes.md`, the retro-spec exports and any project-facing SDD analysis — is written in the project's **working language**, declared in the project-owned Layer-3 rule `.claude/rules/project-working-language.md` (the canonical subject owner; an existing equivalent project rule counts). When no such rule exists, use the language the user works in. The framework hard-codes no universal SDD language: French, English or another language are equally valid project choices.

The working language never overrides the universal engineering invariants: **Git commit subjects are written in English** (`01-git-conventions.md`) and **source-code comments are written in English**, concise, and explain the code — never the SDD process (`03-code-quality.md`). The working-language rule owns **project-facing SDD communication only**: it never changes the language of product source, source comments, technical documentation or other engineering artifacts — English remains the default engineering language for those domains unless a future explicit framework policy establishes another owner. A working-language rule is never evidence about source-comment language.

---

## Anatomy of a spec

A spec states the **WHAT and the WHY** — the expected behavior and its rationale, readable by product/business stakeholders and developers alike. It is never an implementation plan: exact source paths, impacted files, class/service/method names, code snippets, build commands and DB implementation details belong to `plan.md`, even when specification-time exploration discovered them. An externally observable contract requirement (e.g. "the existing API response stays backward compatible", or a business calculation formula that is itself the required behavior) legitimately belongs in the spec — implementation code and internal design never do.

A valid spec contains these sections, in this order:

1. **Frontmatter**: feature, status, created, author
2. **Context and problem**: what we want to solve and why
3. **Objectives**: what the feature must accomplish
4. **Out of scope**: what we are **not** doing in this feature
5. **Functional behavior**: the expected business/functional behavior — business rules, user-visible flows, and the externally observable contracts that are part of the request
6. **Acceptance criteria**: measurable criteria in the format *"When X, the system Y and Z"*
7. **Security considerations**: data sensitivity, authorization impact, external inputs, abuse cases — at the observable requirement level; filled, or its non-applicability justified in one line
8. **Technical constraints**: externally observable constraints that are part of the requested contract (standards, measurable thresholds, compatibility commitments)
9. **Open questions**: what has not been settled

### Quality criteria for a spec

- ✅ Every AC is testable (a test can be written to validate it)
- ✅ Every AC is measurable (binary: passes or does not pass)
- ✅ Out of scope is explicit (reduces scope creep)
- ✅ Structurally significant open questions are resolved **before** approval
- ✅ Security considerations are filled, or their non-applicability is justified in one line
- ❌ No vague ACs like "the system must be performant"
- ❌ No undefined jargon

---

## Anatomy of a plan

The plan is the **technical design artifact — it owns the HOW**: architecture and technical approach, endpoints and internal API implementation, entities/data-model implementation and migrations, services, repositories, mappers, controllers, frontend components/state, integrations, the exact impacted files and class/method placement, the migration strategy and the AC → test mapping. It references the approved behavior of the spec and explains how to implement it — it never duplicates the spec.

A valid plan contains:

1. **Frontmatter**: feature, status, created, author
2. **Overall approach**: implementation strategy
3. **Technical design**: the concrete design — endpoints, data model and migrations, services/components, integrations, class/method placement
4. **Implementation order**: logical sequence
5. **Impacted files**: list with annotation (created, modified, deleted)
6. **Risks and mitigations**: what can go wrong
7. **Test strategy**: which tests cover which ACs
8. **Points of attention**: side effects, non-regressions to check
9. **Remaining questions**: the spec's open questions to resolve before the Tasks phase

---

## Anatomy of a tasks.md

A valid `tasks.md` contains:

1. **Frontmatter**: feature, status, created, author
2. **Reminder**: the task-format rules recap at the top of the file (markers, `[P]`, `Blocked by`)
3. **Overview**: total tasks, number of implementation phases, overall estimate, dependencies on other features
4. **Tasks**, grouped into **implementation phases** (not to be confused with the 4 SDD phases Specify/Plan/Tasks/Implement), in the strict format:

```markdown
### Phase 1: <Milestone name>

- **Goal**: one line — the coherent, revertable state this phase leaves the codebase in
- **Phase commit SHA**: *(filled in by /sdd-implement after the phase squash)*
- **Rollback**: how to undo the phase if it ships broken — default: revert of the phase commit; read by /sdd-revert. An absent line is accepted by /sdd-verify and means the default; an empty line is reported

- [ ] T001 [Category] Short description of the task
  - **Done when**: testable completion criterion
  - **Files**: list of files touched
  - **Tests**: test suite to run afterwards
  - **Commit SHA**: *(local commit — replaced by the phase SHA after squash)*
```

Task numbering is **global and continuous** (T001…TN across all phases). A small feature has **exactly one phase**; a larger feature is split into coherent milestones. A `tasks.md` without `### Phase` headings is treated as **one implicit phase** covering all tasks. Exception: **hotfixes are exempt from the phase squash** (the red-test commit must stay visible before the fix commit).

### Task state markers

| Marker | State | Set by |
|---|---|---|
| `- [ ]` | pending | `/sdd-tasks` at creation |
| `- [~]` | in progress | `/sdd-implement` when starting the task |
| `- [x]` | done (SHA filled in) | `/sdd-implement` after the commit |

These three markers are the **only** valid ones. A task left `- [~]` counts as **not done** for `/sdd-verify` and `/sdd-status`.

### Criteria for an atomic task

- Achievable in 30 min to 2 h max
- A single concept or main file touched
- Independently testable
- Results in a single local commit

If a task is expected to exceed 2 h → **re-split** before approving `tasks.md`.

### Task categories

Task categories depend on the stack (backend, frontend, infra, tests, docs...). They are defined in the project's Layer 2. **The common core does not impose any categories**.

---

## Implementation discipline

### One task per `/sdd-implement` invocation

This is the golden rule. Never chain tasks automatically. Between each task, a human must validate:
- The produced diff
- The test results
- The commit's conformity

### One local commit per task, one branch commit per phase

During development, each task produces **exactly one local commit** (this preserves traceability and human validation between tasks). If the implementation generates several sub-modifications, they go into the same local commit.

When the **last task of an implementation phase** completes, `/sdd-implement` **squashes the phase's task commits into a single commit** — always before the phase's first push. The history presented to reviewers therefore contains **one commit per phase** (plus at most one final SDD-bookkeeping commit, formatted by the effective Git policy of `01-git-conventions.md`): a small feature (one phase) is reviewed as a single code commit.

### The commit SHAs are tracked in `tasks.md`

After `/sdd-implement`, the task is checked off and its local commit SHA is added. At phase squash, the per-task SHAs of the phase are **replaced by the phase commit SHA** (the local SHAs become unreachable after the squash) and the `**Phase commit SHA**` field is filled in. This keeps the traceability chain: one AC ↔ one task ↔ one phase commit.

### Pre-commit hooks are mandatory

Never `git commit --no-verify`. If a hook blocks, there is a quality problem to fix.

---

## Production Hotfix

For urgent Production fixes, the SDD discipline may be lightened:

- Minimal `spec.md`: one paragraph of context + fix ACs
- No detailed `plan.md` if there is a single task
- `tasks.md` may fit in 1-2 lines
- **But** a test reproducing the bug is mandatory before the fix
- **And** the spec must still be completed after the hotfix (status `implemented`)
- Hotfix commits are **not squashed**: the red-test commit stays visible before the fix commit

---

## Rolling back a feature

When a shipped feature (or one of its implementation phases) must be withdrawn, do not fix backward by hand: the one-phase-one-commit discipline makes rollback mechanical.

```
/sdd-revert <FEATURE-ID>              # whole feature (all phases, newest first)
/sdd-revert <FEATURE-ID> "Phase 2"    # single implementation phase
```

The command builds a `git revert` plan from the commit SHAs recorded in `tasks.md`, executes it on a dedicated branch after explicit confirmation, re-runs the tests, and annotates the SDD artifacts (never deletes them). See `/sdd-revert` for the full rules.

---

## Reverse engineering

To document legacy code without implementing anything:

```
/retro-spec <FEATURE-ID>-<description> [<target>] [--format <trame>]            # analysis
/retro-spec <FEATURE-ID>-<description> --export jira|word|all [--format <trame>]  # exports only, on an existing retro spec
```

The target may be a module directory (recommended granularity — business readers think in modules), a screen/component, a URL/route or a single file. The command produces a retrospective spec with `status: implemented` directly, and can optionally derive business-facing deliverables (Jira story, SPEC document) into the feature's `exports/` folder. Useful for catching up on documentation debt before a refactor.

---

## Evolving the methodology

This methodology can evolve. Changes are made:

1. Through a team discussion
2. With an MR on the toolkit's `core/`
3. Once merged, propagated to projects by upgrading the core (without touching Layer 2)

**Any change to this file must be validated by the team**, not by an agent.

---

## Context recovery

When the Claude Code session is lost (context cleared, `/clear`, resuming the next day, switching machines), resume with the following prompt:

```
I'm resuming work on feature <TICKET-ID>-<description>.

Read in this order:
1. .claude/sdd/<TICKET-ID>-<description>/spec.md
2. .claude/sdd/<TICKET-ID>-<description>/plan.md
3. .claude/sdd/<TICKET-ID>-<description>/tasks.md
4. .claude/sdd/<TICKET-ID>-<description>/notes.md

Summarize the current state:
- Which SDD phase are we in (Specify / Plan / Tasks / Implement / Verify / Review)?
- What is the next concrete action?
- Are there any blockers or open questions in notes.md?
```

Claude reads the 4 artifacts, identifies the next `pending` task, and picks up where you left off — without needing to re-explain the whole context.

### Best practice: fill in `notes.md` before closing a session

Before closing Claude Code, add to `notes.md`:

```markdown
## Session of <date>

### What was done
- T001 ✅ — UserService service created (sha: abc1234)
- T002 ✅ — controller created (sha: def5678)

### Next action
Implement T003 [Frontend] — UserList component

### Points to watch
- The user-lookup service returns null if the user does not exist — to be handled on the frontend side
```

This "end-of-session snapshot" is the most effective way to resume quickly.
