---
description: SDD hotfix — lightweight SDD workflow for urgent Production fixes
---

# /sdd-hotfix

**Lightweight workflow** for urgent Production fixes. Initializes an SDD folder with a minimal spec and a `hotfix/` branch.

> This command is the **only exception** to the "spec.md approved before any code" rule. It enables a lightweight mode, not an absence of discipline.

## Usage

```
/sdd-hotfix <TICKET-ID>-<description-kebab>
```

Example:
- `/sdd-hotfix PROJ-180-crash-login-null-pointer`

## Prerequisites

- The Git working tree must be clean
- The feature must not already exist in `.claude/sdd/`

## Steps

### 1. Create the hotfix branch

Read `.claude/rules/20-git-conventions.md` for the convention. For a hotfix, the branch starts from the production branch (often `main` or `master`, never `develop`):

```bash
git checkout main    # or master depending on the project
git pull
git checkout -b hotfix/<TICKET-ID>-<description>
```

### 2. Create the feature folder

```
.claude/sdd/<TICKET-ID>-<description>/
├── spec.md     ← pre-filled hotfix template (see below)
├── tasks.md    ← pre-filled hotfix template
└── notes.md    ← empty
```

**Note**: `plan.md` is optional for a hotfix if the fix is a single task.

### 3. Pre-fill `spec.md` with the hotfix template

```markdown
---
feature: <TICKET-ID>-<description>
status: draft
created: <date>
author: <git config user.name>
type: hotfix
---

# Hotfix: <Short title>

## Problem in Production

<!-- Describe the bug precisely: symptom, impact, frequency -->

## Identified cause

<!-- If already known, note it here. Otherwise leave empty. -->

## Acceptance criteria

- [ ] The bug described above no longer reproduces
- [ ] An automated test reproducing the bug is present and green
- [ ] Adjacent functionality is not regressed

## Out of scope

- Refactoring or improving the affected code (outside the hotfix scope)

## Open questions

<!-- Is there a risk of corrupted data that needs manual fixing? -->
```

### 4. Pre-fill `tasks.md` with the hotfix template

```markdown
---
feature: <TICKET-ID>-<description>
status: draft
created: <date>
author: <git config user.name>
type: hotfix
---

# Hotfix tasks: <Title>

- [ ] T001 [Test] Write the test that reproduces the bug (must be red)
  - **Done when**: red test confirming the bug
  - **Files**: [to be identified]
  - **Tests**: [suite to run]
  - **ACs covered**: AC-2

- [ ] T002 [Fix] Fix the bug (test T001 must turn green)
  - **Done when**: T001 green + no regression
  - **Files**: [to be identified]
  - **Tests**: [full suites]
  - **ACs covered**: AC-1, AC-2, AC-3
  - **Blocked by**: T001
```

### 5. Announce in the chat

```
🚨 Hotfix initialized: <TICKET-ID>-<description>

Branch: hotfix/<TICKET-ID>-<description> (from main)
Mode: lightweight SDD workflow

Hotfix reminders:
  1. Complete spec.md (context + minimum ACs)
  2. Set spec.md to status: approved manually
  3. Write the test that reproduces the bug FIRST (T001)
  4. Fix it (T002) — the test must turn green
  5. Run /sdd-verify
  6. MR to main AND backport to develop

After the hotfix: complete spec.md if needed and set it to status: implemented.
```

## Mandatory hotfix rules

- ❌ **Never bypass** with `git commit --no-verify`
- ✅ **A test reproducing the bug is mandatory** before the fix (T001 before T002)
- ✅ **MR to main** (prod branch) + **backport to develop** (so the fix is not lost)
- ✅ **Complete spec.md** after the hotfix if the context was incomplete
- ❌ **Do not take advantage of the hotfix** to refactor or improve — minimal scope
