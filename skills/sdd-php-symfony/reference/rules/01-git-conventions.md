# Git Conventions — Universal

> **Layer 1 — Universal methodology.**  
> These conventions apply to all projects, regardless of the technology used.

---

## Integration branch

Default: `develop`.

If the project uses another name (`main`, `master`, `integration`), the project's Layer-3 Git rule declares it (see *Project-configurable extension points* below).

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
chore/PROJ-200-bump-framework-7-4
docs/COMMON-100-sdd-workflow
hotfix/PROD-1234-urgent-fix
```

### Rules

- The `<TICKET-ID>` must match **exactly** the ticket in the ticketing tool (Jira, GitHub Issues, etc.)
- The `<description>` must be in kebab-case (words separated by hyphens)
- No accents, no uppercase, no special characters
- 5 words maximum in the description (otherwise shorten)

A project may configure this branch model through its Layer-3 Git rule (see *Project-configurable extension points* below): this file states the universal defaults, not a mandate.

## Commit convention

Everything in this section states the **universal default** — the exact commit-message format is a **project-configurable extension point** (see below): a project's Layer-3 Git rule may adopt a different exact format (e.g. Conventional Commits). The *Absolute prohibitions* remain universal invariants under any configured format.

Format: **the ticket, then the subject**.

```
<TICKET-ID>: <imperative lowercase description without trailing period>
```

The message is the **subject line only** — no body, no footer, no signature.

**No type in the commit message.** The type (`feature`, `fix`, `refactor`, `chore`, `docs`, `hotfix`) lives in the **branch name** and nowhere else: the branch already declares the nature of the work, and every commit of the branch inherits it. Repeating it on each subject line costs characters out of the 72 available and adds a second taxonomy to keep in sync with the first.

### Strict rules

**Subject (1st line)**:
- Maximum **72 characters** (ticket included)
- **Lowercase imperative**: "add", "fix", "refactor" (not "added" nor "addition of")
- **No trailing period**
- **No technical jargon without business context**: "add index on certificate" rather than "modify schema"

**No body**:
- The message is the subject line only — keep it short
- The why lives in the SDD artifacts (spec.md, plan.md) and the MR description, not in the commit

### Valid examples

```
PROJ-101: fix header field initialization
```

```
PROJ-110: add csv export endpoint
```

```
PROJ-103: extract business validation into a dedicated service
```

### Invalid examples

```
Update file.php                              ❌ no ticket
fix: fix bug                                 ❌ no ticket
feat(PROJ-101): add csv export endpoint      ❌ not the universal default — under it, the type lives in the branch (a project policy may adopt a typed format via the extension point)
PROJ-101: Fixed the bug.                     ❌ uppercase + period
PROJ-101: fixing of the bug                  ❌ "fixing of" instead of "fix" (imperative)
PROJ-101: add a new service that allows managing csv exports of business data   ❌ subject > 72 chars
```

## Commit discipline: one local commit per task, one pushed commit per phase

During development, each `T00X` task in `tasks.md` must result in **exactly one local commit**. If the implementation generated several micro-commits, squash them into the task's commit.

When the last task of an implementation phase completes, `/sdd-implement` **squashes the phase's task commits into a single commit** — mandatory before the phase's first push. The pushed history contains **one commit per phase**, plus at most one final `<TICKET-ID>: update SDD artifacts` commit (bookkeeping only, no code). A single-phase feature is therefore reviewed as a single code commit. Note that the squash fires **only when the phase's last task is checked off**: mid-phase, seeing one commit per task on the branch is the expected state, not a missing squash.

The recipe (interactive rebase is not available to agents) — `reset --soft` rewrites history, so the two guards are part of the recipe, not optional:

```bash
BASE=$(git rev-parse <first-task-sha-of-phase>^)
git rev-list "$BASE"..HEAD    # must list exactly the phase's task SHAs, nothing else
git diff --cached --quiet     # must succeed: nothing staged
git reset --soft "$BASE"
git commit   # single phase commit
```

A foreign commit in the `$BASE..HEAD` range (typically a merge from the integration or release branch pulled in mid-phase) or a staged change would be **silently swallowed** into the phase commit. If either guard fails, do not squash: keep the per-task commits and document the phase in `notes.md`, exactly as for a phase pushed mid-phase.

The phase commit message follows the standard format — `<TICKET-ID>: <phase summary in imperative lowercase>` — subject line only; the squashed tasks stay traceable in `tasks.md`.

If a task turns out to be more complex than expected and requires several commits, it is usually a sign that it should have been re-split. Document in `notes.md` for future adjustment of the task breakdown.

## Project-configurable extension points (Layer 3)

This file is framework-owned and identical in every project — it is never edited in place. Project-specific Git configuration lives in **one** project-owned Layer-3 rule (canonical name: `project-git-workflow.md`; an existing equivalent project Git rule counts). That rule may configure **only** the extension points declared here:

- **integration branch** (universal default: `develop`)
- **production branch** (universal default: `main`)
- **feature branch pattern** (universal default: `<type>/<TICKET-ID>-<description-kebab-case>`)
- **ticket prefix** (no universal default — project-defined)
- **exact commit-message formatting** (universal default: `<TICKET-ID>: imperative lowercase subject, no trailing period`, subject line only; **no-ticket maintenance default** — framework/tooling work without a ticket, e.g. an SDD upgrade — replaces the ticket id with the `sdd` marker: `sdd: <imperative subject>`)
- **release branch policy**, **hotfix branch policy**, **backport policy**, **tag policy** (universal defaults: the workflows described in this file)

Everything in *Absolute prohibitions* below — the generated-trailer ban included — is a **universal invariant**, never an extension point.

## Effective Git policy resolution

Every command or agent that composes a branch name or a commit message resolves the **effective Git policy** the same way — it never hard-codes its own exact format:

1. read the universal invariants and defaults from this file;
2. discover **zero or one** applicable Layer-3 project Git rule (canonical: `project-git-workflow.md`, or the project's existing equivalent);
3. that rule may configure only the extension points declared above — anything else it states is project documentation, not policy;
4. if no project Git rule exists, the universal defaults apply as-is;
5. if **several** project Git sources configure the same extension point, or a configured value contradicts a universal invariant: **fail loudly and ask** — never pick a winner silently.

## Absolute prohibitions

❌ **Never `git commit --no-verify`**: if a pre-commit hook blocks, there is a quality problem to fix, not to bypass.

❌ **Never `git push --force` on the integration or production branch**. On your own feature branch: allowed after a rebase, but with caution (prefer `--force-with-lease`).

❌ **Never commit directly on the integration branch**. Everything goes through a feature branch and an MR.

❌ **Never mix several tasks in one local commit** during development. One local commit = one task. The phase squash is the only sanctioned regrouping.

❌ **Never push mid-phase**. Push only after the completed phases have been squashed. If it happened anyway, skip the squash for that phase and document it in `notes.md`.

❌ **Never force a squash past a failed guard** (pushed commits, non-contiguous history, staged changes). The unsquashed phase is a documented exception, not an error to hide.

❌ **Never commit secrets** (API keys, passwords, tokens). If it happened: `git reset`, add to `.gitignore`, and revoke the secret.

❌ **Never add a `Co-Authored-By` trailer — nor any tool-generated trailer** (`Generated with…`, `Signed-off-by` added by a tool, or any other footer an assistant or harness appends by reflex). The message is the subject line only; this prohibition is absolute, with no exception, and it must be honored **at the moment the message is composed** — an agent whose harness injects such a trailer must strip it before committing.

The canonical list below is the **machine-enforced subset** of that prohibition: `scripts/audit.sh` extracts these entries verbatim (literal markers, one per line) and fails on any shipped file that mentions one without negating it. The wider prohibition above ("or any other footer…") remains a **semantic rule enforced by human review** — a newly observed trailer family is only caught automatically once it is added to this list.

- Forbidden trailer: "Co-Authored-By"
- Forbidden trailer: "Generated with Claude"
- Forbidden trailer: "Generated with [Claude Code]("
- Forbidden trailer: "Signed-off-by"

## Typical ticket → merge workflow

```
1. git checkout <integration-branch>
2. git pull
3. git checkout -b <type>/<TICKET-ID>-<description>
4. [SDD loop]
   /sdd-start → /sdd-spec → /sdd-plan → /sdd-tasks
   /sdd-implement (loop: one local commit per task, squash to one commit per phase)
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

Hotfix branches are **exempt from the phase squash**: the red-test commit (T001) must stay visible before the fix commit (T002) in the history.

## Special cases

### Several "fixup" commits during development

Acceptable during local development. **Before push, squash** to honor "one commit per phase", using the `reset --soft` recipe:

```bash
BASE=$(git rev-parse <first-commit-to-squash>^)
git reset --soft "$BASE"
git commit
```

### Modifying a commit already pushed on a feature branch

Allowed via `git push --force-with-lease`. Prefer this form over `--force` to avoid overwriting another developer's work.

This does **not** apply to the phase squash: once a phase's task commits are pushed, do not rewrite them — skip the squash for that phase and document it in `notes.md` (see "Never push mid-phase").

### Rebase vs Merge on the integration branch

To be defined per project in a local convention. Default recommendation:
- **Rebase** the feature branch onto the integration branch before push (linearity)
- **Explicit merge commit** when integrating via the MR (traceability)
