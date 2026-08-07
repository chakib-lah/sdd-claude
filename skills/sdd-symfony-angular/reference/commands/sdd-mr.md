---
description: SDD post-review — generates the minimal Merge Request body from spec.md and tasks.md
---

# /sdd-mr

**Post-review command**: generate the minimal GitLab/GitHub Merge Request body from the active feature's SDD artifacts.

## Blocking prerequisites

- `/sdd-review` must have been run and passed (all gates green)
- `spec.md` must have `status: approved`
- `tasks.md` must have all tasks `done`

If a gate is not green, **refuse**:

> Not all gates are green yet. Run `/sdd-verify` then `/sdd-review` before generating the MR.

## Steps

### 1. Detect the active feature

From the current Git branch.

### 2. Load the SDD artifacts

Read:
- `.claude/sdd/<feature>/spec.md`
- `.claude/sdd/<feature>/tasks.md`

### 3. Extract the key information

From `spec.md`:
- Ticket ID (from the `feature:` frontmatter)
- Title (from the H1)
- Context and problem

From `tasks.md`:
- The implementation phases' names/goals and the task descriptions, to write a **short summary** of the changes made (a few sentences, not a list)

### 4. Determine the target integration branch

Read `.claude/rules/20-git-conventions.md` to identify the target branch (often `develop`).

### 5. Generate the MR body

GitLab/GitHub Markdown format. This model is **fixed**: the same two sections for every MR, no extra sections, no per-MR variations. The details (ACs, tests, files touched, vigilance points) stay in the SDD artifacts and the commits — not in the MR description.

```markdown
## 🎯 Context

closes <TICKET-ID>

<Summary of the context and problem — 2-3 sentences from spec.md>

## 🔧 Changes

<Short summary of the changes made — 2-4 sentences, no exhaustive list>
```

### 6. Display in the chat

Display the generated text ready to copy-paste into GitLab/GitHub.

Add below it:

```
💡 Next steps:
1. Paste this body into your GitLab/GitHub MR
2. After the merge, set spec.md to status: implemented
3. Run /sdd-archive to archive the artifacts
```

## Stop rules

- **Read-only**: no file modified
- **Do not push** automatically
- **Do not create the MR** via API: only display the content to copy
