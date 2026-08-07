---
description: SDD phase 4 — implements ONE task (code + tests + local commit), one per invocation; squashes the phase into one commit when its last task completes
---

# /sdd-implement

**SDD Phase 4**: execute **a single** task from `tasks.md` end-to-end (code → tests → local commit). When the task completes its **implementation phase**, squash the phase's commits into one.

## Blocking prerequisites

- The active feature's `tasks.md` must have `status: approved`
- If `status` is not `approved` → **refuse** with:

  > tasks.md is not in `status: approved`. Review and validate the task breakdown before re-running `/sdd-implement`.

- The Git tree must be clean at startup — **except** pending SDD-artifact bookkeeping under `.claude/sdd/<feature>/` (the `tasks.md` updates written after the previous commit), which rides in this task's commit

## Golden rule

> **One single task per invocation.** Never chain tasks automatically.

Each task still produces one **local** commit; the branch history shown to reviewers is **one commit per implementation phase**, produced by the phase squash (step 11b) when the phase's last task completes.

## Steps

### 1. Detect the active feature

Identify the feature from the Git branch.

### 2. Read `tasks.md` and identify the next task

### 2b. Check the `Blocked by` field

Read the `**Blocked by**` field of the next task.

If the field references a blocking task (e.g. `T002`) and that task is not yet `done` (not checked `- [x]`), **refuse** with:

> T00X is blocked by T00Y, which is not finished yet.  
> Implement T00Y first via `/sdd-implement`, then come back to T00X.

If the field says `*(none)*` or is empty, continue normally.


Priority order:
1. First task in `in_progress` (the user may have suspended it)
2. Otherwise, first task in `pending` (unchecked `- [ ]`)

If all tasks are `done`:

```
✅ All tasks are complete.

Next step: /sdd-verify for the technical gate.
```

### 3. Confirm the chosen task

Display in the chat:

```
Selected task: T00X [Category]
Description: ...
Done when: ...
Main files: ...
Tests to run: ...
ACs covered: AC-1, AC-3

OK to start this task?
```

Wait for the user's explicit confirmation. **Do not start without validation.**

### 4. Load the conventions and skills

Before writing any code, load:

- `.claude/rules/00-sdd-framework.md` (methodology)
- `.claude/rules/10-code-conventions.md` if present (stack code conventions)
- `.claude/rules/20-git-conventions.md` (universal Git conventions)
- `.claude/rules/30-tests-strategy.md` if present (test strategy)
- `.claude/rules/40-quality-gates.md` if present (quality gates)
- Relevant skills in `.claude/skills/` depending on the nature of the task
- Templates in `.claude/sdd/_template/` if applicable

### 5. Mark the task `in_progress`

Update `.claude/sdd/<feature>/tasks.md`:

```markdown
- [~] T00X [Category] ... ← in_progress marker
```

(`[ ]` pending · `[~]` in progress · `[x]` done — the only valid markers, see `.claude/rules/00-sdd-framework.md`.)

### 6. Implement the code

Strictly follow the stack's technical rules (loaded in step 4). Modify only the files planned in the task, unless an unforeseen dependency emerges — in that case, **stop and ask** rather than widening the scope.

If a structural surprise appears (ambiguous spec, missing dependency, flaky test…):
- **Stop the implementation**
- Keep the task `in_progress`
- Add a note in `.claude/sdd/<feature>/notes.md`
- Ask the user what to do

### 7. Run the tests

Run the test suites listed in the task. The exact commands depend on the project (read `.claude/rules/30-tests-strategy.md`).

**If a test fails**:
- **NEVER** disable the test to unblock
- Either fix the code (the most common case)
- Or update the test if the change makes it obsolete (and justify it in the commit)
- Or, when in doubt, stop and ask

### 8. Run the quality gates

Run the quality tools defined in `.claude/rules/40-quality-gates.md`. If one fails, fix it before continuing.

**If a tool offers automatic fixes** (linter --fix, formatter, etc.), apply them in the **same commit** unless they are very large (in which case, a separate commit).

### 9. Review the diff

Before committing, display the diff and validate it mentally:
- Are we staying within the scope of the task?
- No TODO left hanging?
- No forgotten console.log / dump / var_dump?
- No accidental modification of files outside the scope?

### 10. Commit (local)

This commit is a **local, per-task commit**: it will be squashed into the phase commit at step 11b when the phase completes. Stage any pending SDD-artifact bookkeeping (from the previous task's step 11) together with the task's changes. Strictly follow `.claude/rules/20-git-conventions.md` for:
- The message format (subject line only, short)
- Including the ticket in the scope

**Never use `--no-verify`**: if a pre-commit hook blocks, diagnose and fix.

Capture the SHA of the resulting commit.

### 11. Update `tasks.md`

- Check the task off: `- [x] T00X ...`
- Fill in the `**Commit SHA**` field with the captured SHA

### 11b. Phase squash (only when the phase is complete)

If, after step 11, **all the tasks of the current task's implementation phase are `- [x]`**, squash the phase's local commits into a single commit. A `tasks.md` without `### Phase` headings counts as **one implicit phase** covering all tasks (squash when the last task completes). **Exception: hotfixes** (`type: hotfix` frontmatter or `hotfix/` branch) are never squashed — the red-test commit must stay visible before the fix commit.

1. **Push guard**: if the branch has an upstream, verify that none of the phase's task commits has already been pushed (e.g. `git merge-base --is-ancestor <first-task-sha-of-phase> @{upstream}` must fail). If any was pushed → **skip the squash**, set `**Phase commit SHA**: *(not squashed — commits pushed mid-phase, see notes.md)*` and log the incident in `notes.md`. `/sdd-revert` will fall back to the per-task SHAs for that phase.
2. **Propose the squash** to the user with the planned phase commit message, and wait for explicit confirmation (same human-validation discipline as between tasks).
3. Execute (never `git rebase -i`, unavailable here):

   ```bash
   BASE=$(git rev-parse <first-task-sha-of-phase>^)
   git reset --soft "$BASE"
   git commit   # single phase commit
   ```

4. Message: `<type>(<TICKET-ID>): <phase summary in imperative lowercase>` — subject line only; the squashed tasks stay traceable in `tasks.md`.
5. Capture the phase SHA → fill in `**Phase commit SHA**`, and **replace every per-task `Commit SHA` of the phase** with the phase SHA suffixed `*(squashed)*` (the local SHAs become unreachable after the squash).

Note: as for per-task commits, the `tasks.md` bookkeeping edit recording the phase SHA rides in the next commit — or, for the feature's final phase, in a tiny trailing `chore(<TICKET-ID>): update SDD artifacts` commit so the tree is clean for `/sdd-verify`.

### 12. Announce in the chat

```
✅ T00X complete.

Commit (local): <SHA> <message>
Tests: ✅ all green
Quality gates: ✅ OK

Next task: T00Y [Category] - <description>

Type `/sdd-implement` to continue.
```

If the task completed its phase, add:

```
✅ Phase N squashed → <phase-SHA> <phase commit message>
```

If there are no tasks left:

```
✅ T00X complete. That was the last task.
✅ Phase N squashed → <phase-SHA>

Branch history: one commit per implementation phase.
Next step: /sdd-verify for the technical gate.
```

## Stop rules (critical)

❌ **One single task per invocation.** Never chain tasks, even if several are trivial. The human discipline of validating between each task is non-negotiable.

❌ **Never `git commit --no-verify`.** If a hook is red, fix the quality problem, don't bypass it.

❌ **Never disable a red test** to "unblock". Fix the code or re-spec.

❌ **Never widen the scope** without asking. If an unforeseen change is needed, stop and ask.

❌ **Do not mark a task `done`** if a single test is red or a quality gate fails.

❌ **Never push mid-phase.** Push only after the completed phases have been squashed (step 11b).

❌ **Never skip the phase squash silently.** The only sanctioned exception is the push guard of step 11b, and it must be documented in `notes.md`.

❌ **Do not modify `spec.md`, `plan.md` or `tasks.md` beyond progress tracking.** The content of these artifacts is frozen once approved. If a structural change is needed, go back through the earlier phases.

---

## Special case — Parallel tasks `[P]`

If the next task is marked `[P]` and is the first of a consecutive group of parallel tasks (several `[P]` in a row), offer the user:

```
Tasks T007 [P], T008 [P], T009 [P] can be executed in parallel.
They are independent of each other.

Options:
  A) Sequential   — safer, merge conflicts impossible (recommended if < 3 tasks)
  B) Subagents    — faster, isolated contexts (recommended if ≥ 3 independent tasks)

Which mode do you prefer? (A/B)
```

### Mode B — Parallel subagents

In mode B, spawn one subagent per `[P]` task with the following instructions:

```
You are an SDD subagent.
Active feature: <FEATURE-ID>-<description>
Assigned task: T00X

Read ONLY:
- .claude/rules/ (all rules)
- .claude/sdd/<feature>/spec.md
- .claude/sdd/<feature>/plan.md
- .claude/sdd/<feature>/tasks.md (for your task only)
- The source files involved in T00X

Implement T00X according to the rules in sdd-implement.md.
One task, one local commit. Do not touch the other tasks.
Never squash: the phase squash is performed by the main agent only.
```

When the `[P]` group completes its implementation phase, the **main agent** performs steps 11 and 11b once, for the whole group.

**Merge conflict handling**: if subagents modify common files, the main agent resolves the conflicts before the last task commit of the group.

**Golden rule**: `[P]` tasks must NEVER modify the same files. If they do, remove the `[P]` marker from `tasks.md` and execute them sequentially.
