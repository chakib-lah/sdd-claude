---
description: SDD release — generates a CHANGELOG from the archived specs
---

# /sdd-changelog

**Release command**: generate a readable CHANGELOG from the SDD artifacts archived in `.claude/sdd/_archive/`.

## Usage

```
/sdd-changelog [--since <date>] [--format <markdown|confluence>]
```

Examples:
- `/sdd-changelog` — full changelog since the beginning
- `/sdd-changelog --since 2026-04-01` — since April 1, 2026
- `/sdd-changelog --format confluence` — Confluence format

## Prerequisites

- At least one feature in `.claude/sdd/_archive/`

## Steps

### 1. Scan `_archive/`

List all archived features with their archive date.

Filter by `--since` if provided.

### 2. For each archived feature, extract

From `spec.md`:
- Ticket ID
- Title (H1)
- Objectives (list)
- Creation date (`created` from the frontmatter)

From `tasks.md`:
- Number of tasks
- Task types (Backend, Frontend, Tests...)

### 3. Group by feature type

Infer the type from the ticket prefix or the task categories:
- `feat` / `feature` → **New features**
- `fix` → **Bug fixes**
- `refactor` → **Technical improvements**
- `chore` → **Maintenance**
- `hotfix` → **Urgent fixes**

### 4. Generate the CHANGELOG

#### Markdown format

```markdown
# CHANGELOG

## [Unreleased] — <today's date>

### ✨ New features

- **PROJ-101** — User search: added search on the list
- **PROJ-103** — CSV export: bulk data export in CSV format

### 🐛 Bug fixes

- **PROJ-102** — Fixed the authentication token refresh on an expired session

### ♻️ Technical improvements

- **PROJ-130** — Extracted the UserService: refactoring to respect the single responsibility principle

### 🔧 Maintenance

- **PROJ-120** — Updated Symfony and doctrine dependencies
```

#### Confluence format

Version adapted for copy-pasting into Confluence (tables, Confluence styles).

### 5. Display in the chat

Display the generated CHANGELOG, ready to copy-paste.

Add below it:

```
💡 You can:
- Paste this content into CHANGELOG.md at the project root
- Paste the Confluence format into your Confluence release page
- Filter by period with --since YYYY-MM-DD
```

## Stop rules

- **Read-only**: no file modified
- **Do not create CHANGELOG.md** automatically — display only
- **Do not invent** features that are not present in `_archive/`
