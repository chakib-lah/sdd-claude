---
description: SDD tracking — displays the state of all active and archived SDD features
---

# /sdd-status

**Tracking command**: display a dashboard of all the project's SDD features.

No blocking prerequisites. Read-only.

## Steps

### 1. Scan the SDD folders

List:
- `.claude/sdd/<feature>/` for each feature in progress
- `.claude/sdd/_archive/<feature>/` for each archived feature

### 2. For each feature in progress, extract the statuses

Read the frontmatter of:
- `spec.md` → status (draft / in-review / approved / implemented)
- `plan.md` → status
- `tasks.md` → status + ratio of done tasks / total + ratio of squashed implementation phases (`Phase commit SHA` filled) / total phases

### 3. Identify each feature's current SDD phase

Determine the feature's current SDD phase (Specify/Plan/Tasks/Implement — not the implementation phases of `tasks.md`) based on the statuses:

| spec.md | plan.md | tasks.md | Tasks done | Current SDD phase |
|---|---|---|---|---|
| draft | - | - | - | Phase 1 — Specify |
| approved | draft | - | - | Phase 2 — Plan |
| approved | approved | draft | - | Phase 3 — Tasks |
| approved | approved | approved | 0/N | Phase 4 — Implement (to be started) |
| approved | approved | approved | X/N (in progress) | Phase 4 — Implement (in progress) |
| approved | approved | approved | N/N | Gate Verify / Review |
| implemented | - | - | N/N | Merged, ready to archive |

### 4. Identify the associated Git branch

For each feature in progress, check whether a matching Git branch exists locally:

```bash
git branch --list "*<FEATURE-ID>*"
```

### 5. Identify the active feature

The active feature = the one whose branch matches the current Git branch. Mark it with `▶` in the report.

### 6. Produce the dashboard

```
═══════════════════════════════════════════════════════════════════
  SDD Dashboard — <Project name>
═══════════════════════════════════════════════════════════════════

  Current branch: <branch>

  ┌────────────────────────────────────────────────────────────┐
  │  Features in progress                                      │
  └────────────────────────────────────────────────────────────┘

▶ <FEATURE-A>-<description>
  SDD phase : Phase 4 — Implement (in progress)
  Spec      : approved ✅
  Plan      : approved ✅
  Tasks     : approved | 3/7 done | impl. phases: 1/3 squashed
  Branch    : feature/<FEATURE-A>-<description>
  Created   : 2026-05-20

  <FEATURE-B>-<description>
  SDD phase : Phase 2 — Plan
  Spec      : approved ✅
  Plan      : draft ⏳
  Tasks     : —
  Branch    : feature/<FEATURE-B>-<description>
  Created   : 2026-05-22

  ┌────────────────────────────────────────────────────────────┐
  │  Archived features (last 5)                                │
  └────────────────────────────────────────────────────────────┘

  <FEATURE-X>-<description>  | implemented | archived on 2026-05-15
  <FEATURE-Y>-<description>  | implemented | archived on 2026-05-10
  ...

═══════════════════════════════════════════════════════════════════
  Total:  2 features in progress  |  N archived
═══════════════════════════════════════════════════════════════════
```

### 7. Suggest actions

At the end of the report, suggest a contextual action:

- If the active feature is in Phase 1 → "Continue with `/sdd-spec`"
- If it is in Phase 4 with remaining tasks → "Continue with `/sdd-implement`"
- If all tasks are done → "Run `/sdd-verify`"
- If Verify is OK → "Run `/sdd-review`"
- If it is `implemented` but not archived → "You can archive it in `.claude/sdd/_archive/`"

## Stop rules

- **Read-only**: no file modification
- **No test execution**: just a status snapshot
- **Do not suggest more than 3 actions**: avoid noise
