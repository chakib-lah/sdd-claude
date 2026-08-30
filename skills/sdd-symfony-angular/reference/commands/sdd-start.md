---
description: SDD init — creates the feature folder and its associated Git branch
---

# /sdd-start

**SDD Phase 0**: initialize a new feature with its folder structure and Git branch.

## Usage

```
/sdd-start <FEATURE-ID>-<description-kebab-case>
```

Examples:
- `/sdd-start PROJ-101-user-search`
- `/sdd-start PROJ-102-auth-token-refresh`
- `/sdd-start PROJ-103-export-csv`

## Blocking prerequisites

- The name must follow the pattern `<TICKET-ID>-<description-kebab-case>`
- No feature with the same name may already exist in `.claude/sdd/`
- The Git working tree must be clean (no uncommitted changes)

If any of these prerequisites is not met, **refuse** and explain why.

## Steps

### 1. Detect the Git context

```bash
git status --porcelain
git branch --show-current
```

If the current branch is not the integration branch (default: `develop`, otherwise as defined in `.claude/rules/01-git-conventions.md`), offer to switch.

### 2. Create the feature branch

Resolve the **effective feature-branch pattern** through the effective Git policy (`.claude/rules/01-git-conventions.md` § Effective Git policy resolution — universal default: `<type>/<TICKET-ID>-<description>`; a project Git rule may configure it). Under the default, ask the user for the `<type>`:

- `feature`: new business functionality
- `fix`: bug fix
- `refactor`: restructuring with no behavior change
- `chore`: maintenance, dependencies, tooling
- `docs`: documentation only
- `hotfix`: urgent Production fix

Create the branch from the integration branch:

```bash
git checkout <integration-branch>
git pull
git checkout -b <feature branch per the resolved pattern>
```

### 3. Create the feature folder

```
.claude/sdd/<FEATURE-ID>-<description>/
├── spec.md       (from _template/spec.md, frontmatter pre-filled)
├── plan.md       (from _template/plan.md, status: draft)
├── tasks.md      (from _template/tasks.md, status: draft)
└── notes.md      (from _template/notes.md, empty)
```

Pre-fill the frontmatter of each artifact with:
- `feature: <FEATURE-ID>-<description>`
- `status: draft`
- `created: <today's date>`
- `author: <git config user.name>`

### 4. Announce in the chat

```
✅ Feature initialized: <FEATURE-ID>-<description>

Git branch: <resolved feature branch>
Folder: .claude/sdd/<FEATURE-ID>-<description>/

Next step: /sdd-spec to write the spec.
```

## Stop rules

- Do **NOT** explore the project's code
- Do **NOT** ask questions about the feature's content
- Do **NOT** generate any spec, plan, or tasks content at this stage
- The role of `/sdd-start` is strictly to set up the scaffold

Exploration and content writing belong exclusively to `/sdd-spec`.
