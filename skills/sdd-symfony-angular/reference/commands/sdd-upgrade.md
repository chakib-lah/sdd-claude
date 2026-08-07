---
description: SDD maintenance — updates the common core (Layer 1) without touching Layer 2 or the project skills (Layer 3)
---

# /sdd-upgrade

**Maintenance command**: update the SDD common core (Layer 1 — methodology) in an existing project, without touching the code conventions (Layer 2) or the domain skills (Layer 3).

## When to use it

- When Layer 1 (the toolkit's `core/`) has evolved (new command, changed behavior)
- When a universal command is missing or has diverged from the expected behavior
- When the spec/plan/tasks templates need to be updated

## Prerequisites

- An SDD framework already exists in the project's `.claude/`
- The Git tree must be clean

## Steps

### 0. Locate the toolkit reference (source of truth)

⚠️ The checklists in this file reflect the toolkit **as of the version that deployed this file** — they may be incomplete if the toolkit has evolved since. **Never audit against this file alone**: always enumerate the reference directory resolved below.

Resolve the reference directory, in this order:

1. `~/.claude/skills/<skill>/reference/` — where `<skill>` is the SDD skill matching this project's stack (`sdd-php-backend`, `sdd-php-symfony`, `sdd-symfony-angular`, `sdd-angular-node`)
2. If no installed skill is found, **ask the user** for the path to the sdd-claude toolkit, then use `<toolkit>/skills/<skill>/reference/`

If the toolkit's `VERSION` file is reachable (at the toolkit root, e.g. two levels above a symlinked skill directory), read it and state the version in the upgrade plan.

Layer 1 scope within `reference/`:

- `reference/commands/` → universal commands only: every `sdd-*.md` plus `retro-spec.md`. Stack scaffolding commands (`symfony-*.md`, `angular-*.md`, `node-*.md`, `php-*.md`…) are Layer 2 — ignore them.
- `reference/rules/` → Layer 1 rules only: `00-sdd-framework.md`, `05-constitution.md`, `20-git-conventions.md`, `50-security.md`. Everything else there is Layer 2 — ignore.
- `reference/templates/` → all files; they deploy to `.claude/sdd/_template/<name>.md`, except `sdd-readme.md` which deploys to `.claude/sdd/README.md` **only if that file does not exist yet**. Once deployed, `.claude/sdd/README.md` is a **live feature index**, not a template: never overwrite it. If its structure must evolve, rebuild it preserving every feature row.

### 1. Audit the existing Layer 1

For every Layer 1 file enumerated in the reference (step 0), compare it with the project's copy: `❌ missing` / `⚠️ divergent` (diff the content) / `✅ present and current`. **A reference file absent from the checklists below is a new addition — audit it all the same.**

When diffing, classify each divergence by nature:

- **Genuine methodology evolution** — new sections, changed behavior → propose to update
- **Project customization** — content the team added deliberately (branch-model overrides, project prefixes…) → propose to keep; if the reference also evolved in the same file, hand-merge rather than overwrite
- **Translation only** — the project's Layer 1 was deployed in another language and the structure maps 1:1 to the reference → no behavioral change. If a whole language flip would result, **ask the user** to choose: keep the project's language (apply only the genuine evolutions, translated) or overwrite with the reference language. Never silently flip the tooling language.

#### 1.1 — Universal commands

Check the presence of each universal command found in `reference/commands/` (the 17 known when this file was deployed):

```
sdd-start        : [✅ present / ❌ missing / ⚠️ divergent behavior]
sdd-spec         : [...]
sdd-clarify      : [...]
sdd-spec-check   : [...]
sdd-plan         : [...]
sdd-tasks        : [...]
sdd-implement    : [...]
sdd-verify       : [...]
sdd-review       : [...]
sdd-mr           : [...]
sdd-archive      : [...]
sdd-status       : [...]
sdd-hotfix       : [...]
sdd-upgrade      : [...]
sdd-changelog    : [...]
sdd-revert       : [...]
retro-spec       : [...]
```

#### 1.2 — Methodology rules

Compare each Layer 1 rule found in `reference/rules/` (see scope in step 0) with the project's `.claude/rules/`:

```
00-sdd-framework.md   : [✅ present / ❌ missing / ⚠️ old version]
05-constitution.md    : [✅ / ❌ / ⚠️ — never overwrite a filled-in constitution]
20-git-conventions.md : [✅ / ❌ / ⚠️]
50-security.md        : [✅ / ❌ / ⚠️]
```

#### 1.3 — Templates

Compare each file found in `reference/templates/` with the project's copy:

```
_template/spec.md     : [✅ / ❌ / ⚠️]
_template/plan.md     : [✅ / ❌ / ⚠️]
_template/tasks.md    : [✅ / ❌ / ⚠️ — blocked-by field missing?]
_template/notes.md    : [✅ structured / ⚠️ empty template (old version)]
sdd/README.md         : [✅ / ❌ / ⚠️ — from reference/templates/sdd-readme.md]
```

### 2. Identify Layers 2 and 3 to preserve

List the files that MUST NOT be touched:

- `.claude/rules/10-code-conventions.md` → Layer 2 (stack conventions)
- `.claude/rules/30-tests-strategy.md` → Layer 2
- `.claude/rules/40-quality-gates.md` → Layer 2
- `.claude/rules/doctrine-conventions.md` → Layer 2
- `.claude/rules/angular-conventions.md` → Layer 2
- `.claude/skills/` → Layer 3 (in its entirety)
- `.claude/commands/<stack>-*.md` → Layer 2 (scaffolding commands)

### 3. Produce the upgrade plan

Display in the chat (example — the actual lists come from the audit in step 1):

```
SDD upgrade plan (Layer 1 only)
Reference: <path resolved in step 0> — toolkit v<X.Y.Z if known>
─────────────────────────────────────────
TO ADD:
  + .claude/commands/<missing-command>.md
  + ...

TO UPDATE:
  ~ .claude/commands/<divergent-command>.md  (reason)
  ~ .claude/rules/<outdated-rule>.md         (reason)
  ~ .claude/sdd/_template/<template>.md      (reason)
  ~ ...

NOT TO TOUCH (Layers 2 and 3 preserved):
  ✓ .claude/rules/10-code-conventions.md
  ✓ .claude/rules/30-tests-strategy.md
  ✓ .claude/rules/40-quality-gates.md
  ✓ .claude/skills/ (in its entirety)
  ✓ .claude/commands/<stack>-*.md

Do you confirm this upgrade?
```

**Wait for explicit confirmation before modifying anything.**

### 4. Apply the upgrade

After confirmation:
- Add the new commands
- Update the identified files
- Fully preserve the Layer 2 and Layer 3 files

### 5. Commit

```
chore(sdd): upgrade SDD core to toolkit v<X.Y.Z>
```

### 6. Announce in the chat

```
✅ SDD Core updated.

Added:   <list of added commands/rules/templates>
Updated: <list of updated files>

Layer 2 (stack conventions): unchanged ✅
Layer 3 (project skills): unchanged ✅
```

## Stop rules

- ❌ **Never audit against this file's embedded checklists alone** — the reference directory resolved in step 0 is the only source of truth; if it cannot be located, stop and ask the user rather than concluding "nothing to upgrade"
- ❌ **Never touch** Layer 2 or Layer 3 files — even if outdated
- ❌ **Never rename** the 17 existing universal commands
- ❌ **Never overwrite** a project's filled-in `05-constitution.md` — only deploy the skeleton where none exists
- ❌ **Never overwrite** `.claude/sdd/README.md` — it is a live feature index; deploy it only where missing, and preserve every feature row if its structure must be rebuilt
- ✅ **Always wait** for explicit confirmation before writing anything
