---
description: SDD post-review — generates the Merge Request body from spec.md, plan.md, and tasks.md
---

# /sdd-mr

**Post-review command**: generate the full GitLab/GitHub Merge Request body from the active feature's SDD artifacts.

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
- `.claude/sdd/<feature>/plan.md`
- `.claude/sdd/<feature>/tasks.md`

### 3. Extract the key information

From `spec.md`:
- Ticket ID (from the `feature:` frontmatter)
- Title (from the H1)
- Context and problem
- Objectives
- Acceptance criteria (full list)

From `tasks.md`:
- List of tasks with commit SHA (format `T001 — description — SHA`)

From `plan.md`:
- Points of vigilance and non-regressions to mention

### 4. Determine the target integration branch

Read `.claude/rules/20-git-conventions.md` to identify the target branch (often `develop`).

### 5. Generate the MR body

GitLab/GitHub Markdown format:

```markdown
## 🎯 Context

closes <TICKET-ID>

<Summary of the context and problem — 2-3 sentences from spec.md>

## ✅ Acceptance criteria

<List of ACs from spec.md, with checkboxes>
- [ ] AC-1: When ...
- [ ] AC-2: When ...

## 🔨 Implemented tasks

| Task | Description | Commit |
|---|---|---|
| T001 | <description> | `<SHA>` |
| T002 | <description> | `<SHA>` |

## 🧪 Tests and quality

- Tests: ✅ all green (see `/sdd-verify`)
- Quality gates: ✅ OK

## ⚠️ Points of vigilance

<Points from plan.md — non-regressions, side effects>

## 📸 Screenshots

<!-- Add screenshots if this is a UI feature -->
```

### 6. Display in the chat

Display the generated text ready to copy-paste into GitLab/GitHub.

Add below it:

```
💡 Next steps:
1. Paste this body into your GitLab/GitHub MR
2. Verify and check the ACs manually after review
3. After the merge, set spec.md to status: implemented
4. Run /sdd-archive to archive the artifacts
```

## Stop rules

- **Read-only**: no file modified
- **Do not push** automatically
- **Do not create the MR** via API: only display the content to copy
