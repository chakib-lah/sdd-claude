---
description: SDD post-merge — archives the artifacts of an implemented feature into _archive/
---

# /sdd-archive

**Post-merge command**: move the SDD artifacts of a completed feature from `.claude/sdd/` to `.claude/sdd/_archive/`, and update the index.

## Blocking prerequisites

- The feature's `spec.md` must have `status: implemented`
- The Git tree must be clean (no uncommitted changes)

If `spec.md` is not `status: implemented`, **refuse**:

> Feature <X> is not `status: implemented` yet. Set the status to `implemented` after your MR is merged, then re-run `/sdd-archive`.

## Usage

```
/sdd-archive <FEATURE-ID>-<description>
```

If no argument is provided, use the feature matching the current Git branch.

## Steps

### 1. Identify the feature to archive

From the provided argument or from `git branch --show-current`.

### 2. Check the status

Read `.claude/sdd/<feature>/spec.md` and verify `status: implemented`.

### 3. Check that the MR is merged (optional but recommended)

**Exception**: if `spec.md` carries `retrospective: true`, skip this check entirely — a retrospective spec is documentation produced without any branch or MR, and is archivable as soon as the team wants it out of the active list. In the step 4 announcement, report plan.md and tasks.md as "not applicable (retrospective)" instead of task counts.

```bash
git log origin/<integration-branch> --oneline | grep <FEATURE-ID>
```

If the feature does not appear to be merged, display a warning (but do not block):

```
⚠️ The branch feature/<FEATURE-ID>-<description> does not seem to be
merged into the integration branch yet. Continue anyway? (y/n)
```

### 4. Move the folder

```bash
mv .claude/sdd/<FEATURE-ID>-<description>/ .claude/sdd/_archive/<FEATURE-ID>-<description>/
```

### 5. Update the index `.claude/sdd/README.md`

- Remove the feature from the "Features in progress" section
- Add it to the "Archived features" section:

```markdown
| Feature | Archived on | Final status |
|---|---|---|
| <FEATURE-ID>-<description> | <date> | implemented |
```

### 6. Commit

```
<TICKET-ID>: archive SDD artefacts post-merge
```

### 7. Announce in the chat

```
✅ Feature archived: .claude/sdd/_archive/<FEATURE-ID>-<description>/

Artifacts preserved:
  - spec.md (status: implemented)
  - plan.md
  - tasks.md (N/N tasks done)
  - notes.md

Index updated: .claude/sdd/README.md

The feature is now archived and will no longer appear in /sdd-status.
```

## Stop rules

- **Do NOT delete the artifacts**: move only, never delete
- **Do NOT archive if the status is not `implemented`**: the status is updated manually by the human after the merge
- **Do NOT modify the content** of the artifacts while moving them
