---
description: SDD rollback — un-ships a feature (or one of its implementation phases) using the commit SHAs tracked in tasks.md
---

# /sdd-revert

**Rollback command**: cleanly undo an SDD feature — or a single implementation phase of it — by exploiting the traceability the method already guarantees: one phase ↔ one commit, with the phase SHA recorded in `tasks.md`.

`/sdd-hotfix` is for fixing forward; `/sdd-revert` is for backing out. Typical uses: a merged feature must be withdrawn from the release, or a specific phase introduced a regression that cannot be fixed forward in time.

## Usage

```
/sdd-revert <FEATURE-ID>              # revert the whole feature (all phases)
/sdd-revert <FEATURE-ID> "Phase 2"    # revert a single implementation phase
```

## Blocking prerequisites

- The feature folder exists in `.claude/sdd/` (or `.claude/sdd/_archive/` for a merged feature)
- `tasks.md` has the `Phase commit SHA` field filled in for the targeted phase(s) — without SHAs, refuse and explain that traceability is missing. Exception: for a phase marked `*(not squashed — <reason>, see notes.md)*` (a guard of `/sdd-implement` step 11b fired) and for hotfixes (exempt from the squash), fall back to that phase's per-task `Commit SHA` fields. A `tasks.md` without `### Phase` headings counts as one implicit phase: its unit of revert is the **deduplicated** set of per-task SHAs (after a squash all tasks share the phase SHA → one single revert); an unsquashed phase reverts each distinct per-task SHA, newest first
- The Git tree is clean
- You are on a **dedicated revert branch** (e.g. `revert/<FEATURE-ID>`), never directly on the integration branch — create it if needed

## Steps

### 1. Locate the feature and load `tasks.md`

Look in `.claude/sdd/<feature>/` first, then `.claude/sdd/_archive/<feature>/`. Collect the implementation phases and their `Phase commit SHA` (falling back to per-task SHAs for a documented unsquashed phase). The trailing SDD-bookkeeping commit, if any (the artifacts-only commit formatted by the effective Git policy — see `02-git-conventions.md`), touches only SDD artifacts and is **not** part of the revert plan.

### 2. Verify the SHAs

For each targeted SHA, verify it exists in the history (`git cat-file -t <sha>`). If a SHA is unknown (rebase, squash-merge), stop and report: the revert must then be prepared manually from the merge commit.

### 3. Build the revert plan

Order the reverts **most recent commit first** (reverse chronological order, newest phase first) to minimize conflicts.

For each phase to revert, read its **Rollback** line in `tasks.md`: anything it lists beyond the revert itself (compensating data migration, feature flag to flip) becomes a manual step to confirm with the user. Display:

```
Revert plan — <FEATURE-ID>
─────────────────────────────────────────
Branch: revert/<FEATURE-ID> (from <integration-branch>)

Will revert (newest first):
  1. git revert <sha-phase-3>   — Phase 3 <name> (T006-T008)
  2. git revert <sha-phase-2>   — Phase 2 <name> (T003-T005)
  3. git revert <sha-phase-1>   — Phase 1 <name> (T001-T002)

Not touched: <phases kept, if partial revert>

Rollback notes (from tasks.md):
  Phase 3: <content of the phase's Rollback line — manual steps beyond the revert>

Do you confirm this revert?
```

**Wait for explicit confirmation before reverting anything.**

### 4. Execute the reverts

After confirmation, run the `git revert` commands one by one. **If a revert conflicts, stop immediately**, report the conflicting files, and let the human resolve or abort (`git revert --abort`). Never resolve a revert conflict silently.

### 5. Run the test suites

A revert can break the code that remains (later features may depend on the reverted one). Run the project's test suites as `/sdd-verify` would. If tests fail, report it — the failure list is the input for a corrective decision, not something to hide.

### 6. Update the SDD artifacts

- In `tasks.md`: annotate each reverted phase — keep the `Phase commit SHA` and the tasks' `[x]` markers, and append `**Reverted by**: <revert-sha>` to the phase's metadata block
- In `spec.md`: do **not** change the `status` (never rewrite history silently) — add a `> ⚠️ Reverted on <date> by <revert-branch>` banner right under the frontmatter, and let the team decide the status afterwards
- In `notes.md`: log the revert (date, reason, reverted SHAs, revert SHAs, test results)

### 7. Announce in the chat

```
✅ Revert prepared on branch revert/<FEATURE-ID>

Reverted: Phase 1, Phase 2, Phase 3 (3 commits — tasks T001-T008)
Tests: ✅ green / ❌ N failures (list)

Next step:
1. Review the diff
2. Push and open an MR to <integration-branch>
3. After merge, update the feature's spec status with the team
```

## Stop rules

- **Never revert without explicit confirmation** of the displayed plan
- **Never work directly on the integration branch** — always a dedicated revert branch, merged via MR
- **Never force-push, never rewrite history** (`revert`, not `reset`)
- **Never resolve revert conflicts silently** — stop and hand over to the human
- **Never delete SDD artifacts** — annotate them; the history of what was shipped and unshipped is part of the traceability
