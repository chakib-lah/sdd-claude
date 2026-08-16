---
description: SDD phase 3 — generates atomic tasks.md from an approved plan
---

# /sdd-tasks

**SDD Phase 3**: produce `tasks.md` with a breakdown into atomic tasks T001, T002, T00N.

## Blocking prerequisites

- The active feature's `plan.md` must have `status: approved`
- If `status` is `draft` or `in-review` → **refuse** with:

  > The plan is not in `status: approved`. Review it, then edit the frontmatter to set it to `approved` before re-running `/sdd-tasks`.

## Steps

### 1. Detect the active feature

Identify the feature from the Git branch, or ask if ambiguous.

### 2. Load the plan and the spec

Read `.claude/sdd/<feature>/plan.md` (status: approved) and `.claude/sdd/<feature>/spec.md` (reference for the ACs).

### 3. Break down into atomic tasks

For each step in the plan's implementation order, identify one or more atomic tasks. Criteria for an atomic task:

- ✅ Achievable in 30 minutes to 2 hours maximum
- ✅ A single concept or main file touched
- ✅ Testable independently of the other tasks
- ✅ Results in a single local commit
- ✅ Has a testable "done" criterion

If a task exceeds the planned 2 hours, break it down further.

### 4. Categorize the tasks

Use categories consistent with the project's stack. Categories are defined in Layer 2, not in the core. Possible examples:

- `[Backend]`, `[Frontend]`, `[Infra]`, `[Tests]`, `[Docs]`
- `[BE-Entity]`, `[BE-Service]`, `[BE-Controller]`, `[FE-Component]`, `[FE-Service]`
- `[DB]`, `[API]`, `[UI]`, `[E2E]`

Choose the clearest convention for the project and apply it uniformly.

### 5. Identify parallelizable tasks

Mark with `[P]` the tasks that can be implemented in parallel (no dependency between them). This makes planning easier if several developers work on the feature.

### 5b. Group tasks into implementation phases

Implementation phases (not to be confused with the 4 SDD phases) group tasks into revertable milestones: each phase is squashed into **one commit** on the branch by `/sdd-implement`.

- Small feature (≲ 5 tasks, or a single concern) → **exactly one phase**
- Larger feature → group by coherent milestone (e.g. DB migration / backend / frontend, or migration / implementation / cleanup), typically 3–8 tasks per phase
- **Invariant**: each phase must leave the codebase consistent (all tests green, no half-wired code), because it becomes one revertable commit
- An AC should be fully covered within a single phase whenever possible
- A `[P]` group must never straddle a phase boundary
- `Blocked by` may cross phases only forward (a task in phase N+1 blocked by a task in phase N, never the reverse)

Task numbering stays global and continuous (T001…TN across all phases).

### 6. Write `tasks.md`

Fill in the template `.claude/sdd/_template/tasks.md` with:

#### Frontmatter
- `feature`, `status: draft`, `created`, `author`

#### Reminder
- Keep the template's format-rules recap at the top of the file (valid markers, `[P]`, `Blocked by`, commit SHAs)

#### Overview
- Total number of tasks
- Number of implementation phases
- Overall duration estimate
- Any dependencies on other features

#### Tasks

Strict format — tasks grouped under their implementation phase:

```markdown
### Phase 1: <Milestone name>

- **Goal**: one line — the coherent, revertable state this phase leaves the codebase in
- **Phase commit SHA**: *(filled in by /sdd-implement after the phase squash)*
- **Rollback**: how to undo this phase if it ships broken — default: revert of the phase commit (`/sdd-revert <FEATURE-ID> "Phase N"`); add anything the revert alone does not cover (compensating data migration, feature flag to flip)

- [ ] T001 [Category] Short, active description of the task
  - **Done when**: testable and observable completion criterion
  - **Files**: list of the main files touched
  - **Tests**: test suite(s) to run after this task
  - **ACs covered**: AC-1, AC-3 (reference to the spec's acceptance criteria)
  - **Blocked by**: *(none)* or T00X
  - **Commit SHA**: *(filled in after /sdd-implement)*

- [ ] T002 [P] [Category] ...
```

Every `[SEC]` acceptance criterion in the spec produces **at least one task tagged `[SEC]`** on its task line, after the `[Category]` field (e.g. `- [ ] T003 [Backend] [SEC] Enforce the ownership check on export`). A `[SEC]` task is never optional — `/sdd-verify` checks that every one of them is done.

### 7. Verify coverage

Confirm that **every acceptance criterion in the spec is covered by at least one task**. If an AC has no task, either add a task or flag the problem (this often means the plan is incomplete).

### 8. Display a summary and ask for validation

Before saving, display in the chat:
- Total number of tasks
- Number of implementation phases (1 phase = 1 final commit on the branch)
- Parallelizable tasks
- Cumulative estimate (if relevant)
- AC coverage check

Ask: *"OK to save this task breakdown with `status: draft`?"*

### 9. Save

Write `.claude/sdd/<feature>/tasks.md`.

### 10. Announce in the chat

```
✅ Tasks written: .claude/sdd/<feature>/tasks.md

Current status: draft
Total tasks: N
Implementation phases: N (1 phase = 1 final commit)
Parallelizable tasks: N
ACs covered: N/N

Next step:
1. Read the task list
2. Check atomicity (each task < 2h)
3. Edit the frontmatter to set status to "approved"
4. Run /sdd-implement (one task at a time)
```

## Stop rules

- **Refuse** if the plan is not `approved` (strict gate)
- **No file modified** in the project's source code (read-only)
- **Do not generate code**: this phase is still planning
- **Do not set the status to "approved" automatically**
- If an AC has no associated task, **flag it** and suggest fixing the plan rather than inventing a task

---

## Full task format (with the `blocked-by` field)

Every task in `tasks.md` lives under a `### Phase N: <name>` heading (see step 5b) and must follow this format:

```markdown
- [ ] T001 [Category] Short description of the task
  - **Done when**: testable, binary completion criterion
  - **Files**: precise list of the files touched
  - **Tests**: test suite(s) to run after implementation
  - **ACs covered**: AC-1, AC-3
  - **Blocked by**: *(none)* or T00X (if this task cannot start before another one is done)
  - **Commit SHA**: *(filled in automatically by /sdd-implement)*
```

### Rule for `Blocked by`

- If the task has no dependency: write `*(none)*`
- If the task depends on another one: write `T00X` (number of the blocking task)
- `/sdd-implement` will check this field and refuse to execute a task whose blocker is not `done`

### Example tasks.md with phases, dependencies and parallelism

```markdown
### Phase 1: Shared contracts

- **Goal**: shared types compiled, ready to be consumed by both sides
- **Phase commit SHA**: def5678

- [x] T001 [Shared] Define the shared TypeScript types
  - **Done when**: interfaces compile without errors
  - **Files**: src/types/user.types.ts
  - **Tests**: tsc --noEmit
  - **ACs covered**: AC-1
  - **Blocked by**: *(none)*
  - **Commit SHA**: def5678 *(squashed)*

### Phase 2: Backend and frontend implementation

- **Goal**: user list feature working end to end
- **Phase commit SHA**: *(filled in by /sdd-implement after the phase squash)*

- [ ] T002 [Backend] Create the UserService service [P]
  - **Done when**: unit tests green
  - **Files**: src/services/user.service.ts, tests/user.service.test.ts
  - **Tests**: npm test -- user.service
  - **ACs covered**: AC-2, AC-3
  - **Blocked by**: T001
  - **Commit SHA**:

- [ ] T003 [Frontend] Create the UserList component [P]
  - **Done when**: component renders with mocked data
  - **Files**: src/app/features/user/user-list.component.ts
  - **Tests**: npm test -- user-list
  - **ACs covered**: AC-4
  - **Blocked by**: T001
  - **Commit SHA**:
```

T002 and T003 are parallel (marked `[P]`), both blocked by T001, and both in the same phase (a `[P]` group never straddles two phases). Phase 1 is complete: its task commit was squashed into the phase commit `def5678`, which replaced T001's local SHA.
