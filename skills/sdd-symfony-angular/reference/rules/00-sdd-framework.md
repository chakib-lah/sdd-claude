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

### The transition to `approved` is manual

This is intentional. Moving to `approved` is the act by which a human takes responsibility for the artifact's content. No agent may do it automatically.

---

## SDD directory structure

```
.claude/sdd/
├── README.md                                  ← feature index
├── _template/                                 ← skeletons
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   └── notes.md
├── _archive/                                  ← merged features
│   └── <FEATURE-XXX>-<description>/
└── <FEATURE-XXX>-<description>/               ← features in progress
    ├── spec.md
    ├── plan.md
    ├── tasks.md
    └── notes.md                               ← free-form logbook
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

Alongside the per-feature artifacts, a project may maintain a **constitution** (`.claude/rules/05-constitution.md`): the durable engineering principles that outlive any single feature, numbered `P1…PN` and **ratified by the team** (`status: ratified` — a human act, like every approval in SDD).

When a ratified constitution exists:
- `/sdd-spec-check` verifies the spec violates no principle (scored criterion)
- `/sdd-review` treats a violation in the diff as a **blocking finding**

Without a ratified constitution, these checks are skipped. The skeleton is deployed with every skill; filling it in is optional but recommended for any team of more than one.

---

## Anatomy of a spec

A valid spec contains these sections, in this order:

1. **Frontmatter**: feature, status, created, author
2. **Context and problem**: what we want to solve and why
3. **Objectives**: what the feature must accomplish
4. **Out of scope**: what we are **not** doing in this feature
5. **Acceptance criteria**: measurable criteria in the format *"When X, the system Y and Z"*
6. **Design**: technical sections (endpoints, entities, components — depending on the stack)
7. **Technical constraints**: decisions and justifications
8. **Open questions**: what has not been settled

### Quality criteria for a spec

- ✅ Every AC is testable (a test can be written to validate it)
- ✅ Every AC is measurable (binary: passes or does not pass)
- ✅ Out of scope is explicit (reduces scope creep)
- ✅ Structurally significant open questions are resolved **before** approval
- ❌ No vague ACs like "the system must be performant"
- ❌ No undefined jargon

---

## Anatomy of a plan

A valid plan contains:

1. **Frontmatter**: feature, status, created, author
2. **Overall approach**: implementation strategy
3. **Implementation order**: logical sequence
4. **Impacted files**: list with annotation (created, modified, deleted)
5. **Risks and mitigations**: what can go wrong
6. **Test strategy**: which tests cover which ACs
7. **Points of attention**: side effects, non-regressions to check

---

## Anatomy of a tasks.md

A valid `tasks.md` contains:

1. **Frontmatter**: feature, status, created, author
2. **Task list** in the strict format:

```markdown
- [ ] T001 [Category] Short description of the task
  - **Done when**: testable completion criterion
  - **Files**: list of files touched
  - **Tests**: test suite to run afterwards
  - **Commit SHA**: *(filled in after /sdd-implement)*
```

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
- Results in a single commit

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

### One commit per task

Each task produces **exactly one commit**. If the implementation generates several sub-modifications, they go into the same commit (squash before push if necessary).

### The commit SHA is tracked in `tasks.md`

After `/sdd-implement`, the task is checked off and the commit SHA is added. This enables perfect traceability: one AC ↔ one task ↔ one commit.

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

---

## Rolling back a feature

When a shipped feature (or one of its tasks) must be withdrawn, do not fix backward by hand: the one-task-one-commit discipline makes rollback mechanical.

```
/sdd-revert <FEATURE-ID>          # whole feature
/sdd-revert <FEATURE-ID> T003     # single task
```

The command builds a `git revert` plan from the commit SHAs recorded in `tasks.md`, executes it on a dedicated branch after explicit confirmation, re-runs the tests, and annotates the SDD artifacts (never deletes them). See `/sdd-revert` for the full rules.

---

## Reverse engineering

To document legacy code without implementing anything:

```
/retro-spec <path/to/code>
```

This command produces a retrospective spec with `status: implemented` directly. Useful for catching up on documentation debt before a refactor.

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
- The UserService service returns null if the user does not exist — to be handled on the Angular side
```

This "end-of-session snapshot" is the most effective way to resume quickly.
