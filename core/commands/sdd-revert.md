---
description: SDD rollback — un-ships a feature (or a single task) using the commit SHAs tracked in tasks.md
---

# /sdd-revert

**Rollback command**: cleanly undo an SDD feature — or a single task of it — by exploiting the traceability the method already guarantees: one task ↔ one commit, with the SHA recorded in `tasks.md`.

`/sdd-hotfix` is for fixing forward; `/sdd-revert` is for backing out. Typical uses: a merged feature must be withdrawn from the release, or a specific task introduced a regression that cannot be fixed forward in time.

## Usage

```
/sdd-revert <FEATURE-ID>              # revert the whole feature
/sdd-revert <FEATURE-ID> T003         # revert a single task
```

## Blocking prerequisites

- The feature folder exists in `.claude/sdd/` (or `.claude/sdd/_archive/` for a merged feature)
- `tasks.md` has the `Commit SHA` field filled in for the targeted task(s) — without SHAs, refuse and explain that traceability is missing
- The Git tree is clean
- You are on a **dedicated revert branch** (e.g. `revert/<FEATURE-ID>`), never directly on the integration branch — create it if needed

## Steps

### 1. Locate the feature and load `tasks.md`

Look in `.claude/sdd/<feature>/` first, then `.claude/sdd/_archive/<feature>/`. Collect the tasks and their commit SHAs.

### 2. Verify the SHAs

For each targeted SHA, verify it exists in the history (`git cat-file -t <sha>`). If a SHA is unknown (rebase, squash-merge), stop and report: the revert must then be prepared manually from the merge commit.

### 3. Build the revert plan

Order the reverts **most recent commit first** (reverse chronological order) to minimize conflicts. Display:

```
Revert plan — <FEATURE-ID>
─────────────────────────────────────────
Branch: revert/<FEATURE-ID> (from <integration-branch>)

Will revert (newest first):
  1. git revert <sha-T005>   — T005 <description>
  2. git revert <sha-T003>   — T003 <description>
  3. git revert <sha-T001>   — T001 <description>

Not touched: <tasks kept, if partial revert>

Do you confirm this revert?
```

**Wait for explicit confirmation before reverting anything.**

### 4. Execute the reverts

After confirmation, run the `git revert` commands one by one. **If a revert conflicts, stop immediately**, report the conflicting files, and let the human resolve or abort (`git revert --abort`). Never resolve a revert conflict silently.

### 5. Run the test suites

A revert can break the code that remains (later features may depend on the reverted one). Run the project's test suites as `/sdd-verify` would. If tests fail, report it — the failure list is the input for a corrective decision, not something to hide.

### 6. Update the SDD artifacts

- In `tasks.md`: annotate each reverted task — keep `[x]` and the original SHA, and append `**Reverted by**: <revert-sha>`
- In `spec.md`: do **not** change the `status` (never rewrite history silently) — add a `> ⚠️ Reverted on <date> by <revert-branch>` banner right under the frontmatter, and let the team decide the status afterwards
- In `notes.md`: log the revert (date, reason, reverted SHAs, revert SHAs, test results)

### 7. Announce in the chat

```
✅ Revert prepared on branch revert/<FEATURE-ID>

Reverted: T001, T003, T005 (3 commits)
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
