# Git Conventions — Universal

> **Layer 1 — Universal methodology.**  
> These conventions apply to all projects, regardless of the technology used.

---

## Integration branch

Default: `develop`.

If the project uses another name (`main`, `master`, `integration`), it is up to Layer 2 or a project override to redefine it.

## Branch naming

Strict format:

```
<type>/<TICKET-ID>-<description-kebab-case>
```

### Allowed types

| Type | When to use it |
|---|---|
| `feature` | New business functionality |
| `fix` | Bug fix |
| `refactor` | Rework without behavior change |
| `chore` | Maintenance, dependencies, tooling |
| `docs` | Documentation only |
| `hotfix` | Urgent Production fix |

### Examples

```
feature/PROJ-101-user-search
fix/PROJ-102-auth-token-refresh
refactor/PROJ-103-export-csv-decoupling
chore/PROJ-200-bump-symfony-7-4
docs/COMMON-100-sdd-workflow
hotfix/PROD-1234-urgent-fix
```

### Rules

- The `<TICKET-ID>` must match **exactly** the ticket in the ticketing tool (Jira, GitHub Issues, etc.)
- The `<description>` must be in kebab-case (words separated by hyphens)
- No accents, no uppercase, no special characters
- 5 words maximum in the description (otherwise shorten)

## Commit convention

Format: **Conventional Commits with the ticket as scope**.

```
<type>(<TICKET-ID>): <imperative lowercase description without trailing period>

[optional body — why and how]

[optional footer — breaking changes, additional refs]

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Commit types

The same as for branches: `feature`, `fix`, `refactor`, `chore`, `docs`, `hotfix`.

Possible additions:
- `test`: adding tests without changing production code
- `perf`: performance improvement
- `style`: style/formatting change without behavior change
- `ci`: CI/CD-related changes
- `build`: build- or dependency-related changes

### Strict rules

**Subject (1st line)**:
- Maximum **72 characters** (ticket included)
- **Lowercase imperative**: "add", "fix", "refactor" (not "added" nor "addition of")
- **No trailing period**
- **No technical jargon without business context**: "add index on certificate" rather than "modify schema"

**Body (optional)**:
- Separated from the subject by a blank line
- Lines ≤ 72 characters
- Explains **the why**, not the what (the diff already shows the what)
- Markdown allowed for lists

### Valid examples

```
fix(PROJ-101): fix header field initialization
```

```
feat(PROJ-110): add csv export endpoint

Answers the business request for bulk export.
The format follows the Squash TM standard for later re-import.

Co-Authored-By: Claude <noreply@anthropic.com>
```

```
refactor(PROJ-103): extract business validation into a dedicated service

Prepares the decoupling of the validation chain planned in PROJ-150.
No behavior change expected.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Invalid examples

```
Update file.php                              ❌ no type, no ticket
fix: fix bug                                 ❌ no ticket as scope
fix(PROJ-101): Fixed the bug.                 ❌ uppercase + period
fix(PROJ-101): fixing of the bug              ❌ "fixing of" instead of "fix" (imperative)
feat(PROJ-101): add a new service that allows managing csv exports of business data   ❌ subject > 72 chars
```

## Co-Authored-By

For commits where Claude (or another AI agent) contributed significantly, add the signature:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

This signature is **recommended** for transparency about AI usage, but not mandatory. Adapt according to the project's or team's policy.

## One-commit-per-task discipline

Each `T00X` task in `tasks.md` must result in **exactly one commit**. If the implementation generated several micro-commits, **squash before push**.

If a task turns out to be more complex than expected and requires several commits, it is usually a sign that it should have been re-split. Document in `notes.md` for future adjustment of the task breakdown.

## Absolute prohibitions

❌ **Never `git commit --no-verify`**: if a pre-commit hook blocks, there is a quality problem to fix, not to bypass.

❌ **Never `git push --force` on the integration branch or main**. On your own feature branch: allowed after a rebase, but with caution (prefer `--force-with-lease`).

❌ **Never commit directly on the integration branch**. Everything goes through a feature branch and an MR.

❌ **Never mix several tasks in one commit**. One commit = one intention.

❌ **Never commit secrets** (API keys, passwords, tokens). If it happened: `git reset`, add to `.gitignore`, and revoke the secret.

## Typical ticket → merge workflow

```
1. git checkout <integration-branch>
2. git pull
3. git checkout -b <type>/<TICKET-ID>-<description>
4. [SDD loop]
   /sdd-start → /sdd-spec → /sdd-plan → /sdd-tasks
   /sdd-implement (loop, one commit per task)
5. /sdd-verify
6. /sdd-review
7. git push -u origin <type>/<TICKET-ID>-<description>
8. Create the MR towards <integration-branch>
9. [Human review + possible fixes]
10. Merge
11. [Optional] mv .claude/sdd/<feature> .claude/sdd/_archive/
```

## Production Hotfix

For urgent Production fixes:

```
1. git checkout <production-branch>  (often: main or master)
2. git pull
3. git checkout -b hotfix/<TICKET-ID>-<description>
4. Lightened SDD: minimal spec + 1-2 tasks max
5. Mandatory tests reproducing the bug
6. Push + MR towards the Production branch
7. Cherry-pick onto the integration branch (develop) after merge
```

## Special cases

### Several "fixup" commits during development

Acceptable during local development. **Before push, squash** to honor "one commit per task".

```bash
git rebase -i HEAD~5
```

### Modifying a commit already pushed on a feature branch

Allowed via `git push --force-with-lease`. Prefer this form over `--force` to avoid overwriting another developer's work.

### Rebase vs Merge on the integration branch

To be defined per project in a local convention. Default recommendation:
- **Rebase** the feature branch onto the integration branch before push (linearity)
- **Explicit merge commit** when integrating via the MR (traceability)
