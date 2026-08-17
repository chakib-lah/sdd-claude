---
description: SDD maintenance — updates the common core (Layer 1) without touching the content of Layer 2 or the project skills (Layer 3)
---

# /sdd-upgrade

**Maintenance command**: update the SDD common core (Layer 1 — methodology) in an existing project, without touching the **content** of the code conventions (Layer 2) or the domain skills (Layer 3) — the only Layer 2 touch allowed is the step 0b file rename.

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

1. `~/.claude/skills/<skill>/reference/` — where `<skill>` is the SDD skill matching this project's stack (`sdd-php-backend`, `sdd-php-symfony`, `sdd-symfony-angular`, `sdd-angular-node`, `sdd-java-backend`, `sdd-java-angular`)
2. If no installed skill is found, **ask the user** for the path to the sdd-claude toolkit, then use `<toolkit>/skills/<skill>/reference/`

If the toolkit's `VERSION` file is reachable (at the toolkit root, e.g. two levels above a symlinked skill directory), read it and state the version in the upgrade plan.

**The reference itself must be fresh — verify it before auditing anything.** An upgrade run against a stale reference reports success while deploying old files:

- On Linux/macOS/WSL2 the installed skills are **symlinks** into the toolkit repo: a `git pull` in the toolkit refreshes them. Ask the user to confirm the toolkit was pulled recently, or check `git -C <toolkit> log -1 --format=%cd` if the repo is reachable.
- **On Windows the installed skills are COPIES** — a `git pull` alone changes nothing under `~/.claude/skills/`: `upgrade-global.ps1` must have been run **since** the pull. If in doubt, ask the user to re-run it before continuing.
- If freshness cannot be checked at all (ZIP install, no git history): state it explicitly in the upgrade plan as a **warning** — "reference freshness unverified (ZIP install)" — and continue. Never hard-block a legitimate offline user; never stay silent about it either.

Layer 1 scope within `reference/`:

- `reference/commands/` → universal commands only: every `sdd-*.md` plus `retro-spec.md`. Stack scaffolding commands (`symfony-*.md`, `angular-*.md`, `node-*.md`, `php-*.md`, `java-*.md`…) are Layer 2 — ignore them.
- `reference/rules/` → Layer 1 rules only: `00-sdd-framework.md`, `01-constitution.md`, `02-git-conventions.md`, `03-security.md`. Everything else there is Layer 2 — ignore.
- `reference/templates/` → all files; they deploy to `.claude/sdd/_template/<name>.md`, except `sdd-readme.md` which deploys to `.claude/sdd/README.md` **only if that file does not exist yet**. Once deployed, `.claude/sdd/README.md` is a **live feature index**, not a template: never overwrite it. If its structure must evolve, rebuild it preserving every feature row.
- `reference/agents/` → the 5 SDD agents (`spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer`, `test-generator`); they deploy to `.claude/agents/<name>.md`. `test-generator` is **stack-adapted**: the skill's reference is the correct source for this project — never compare it against another skill's copy. Files in `.claude/agents/` that do not exist in the reference are the developer's own agents — **never touch them**.

### 0b. Apply pending file renames (migration map)

The toolkit may have renamed Layer 1/Layer 2 files between versions. Before auditing, **rename** any project file still under an old name (a pure rename: content untouched, customizations preserved).

**Read the project's deployed SDD version first**: `.claude/sdd/.sdd-version` (one line, written by the previous `/sdd-upgrade`). If it exists and is ≥ the version a map entry was introduced in, **skip that entry** — the rename already happened. If the file is absent (install older than the marker), apply the full map. Current map (introduced in v1.3.0):

| Old name (in `.claude/rules/`) | New name |
|---|---|
| `05-constitution.md` | `01-constitution.md` |
| `20-git-conventions.md` | `02-git-conventions.md` |
| `50-security.md` | `03-security.md` |
| `30-tests-strategy.md` | `11-tests-strategy.md` |
| `40-quality-gates.md` | `12-quality-gates.md` |

Renaming the two Layer 2 files (`11-tests-strategy`, `12-quality-gates`) is the **one sanctioned touch on Layer 2** — a rename is not a content change, and the upgraded Layer 1 commands reference the new names. If both old and new names exist, stop and ask the user which content to keep.

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
01-constitution.md    : [✅ / ❌ / ⚠️ — never overwrite a filled-in constitution]
02-git-conventions.md : [✅ / ❌ / ⚠️]
03-security.md        : [✅ / ❌ / ⚠️]
```

#### 1.3 — Templates

Compare each file found in `reference/templates/` with the project's copy. A template present in the project's `_template/` but absent from the reference (e.g. a `spec-doc-<lang>.md` trame saved by `/retro-spec` for a language with no shipped variant) is a **project-own trame — never touch it**:

```
_template/spec.md     : [✅ / ❌ / ⚠️]
_template/plan.md     : [✅ / ❌ / ⚠️]
_template/tasks.md    : [✅ / ❌ / ⚠️ — phase structure (### Phase N) missing?]
_template/notes.md    : [✅ structured / ⚠️ "Squash exceptions" section missing (old version)]
_template/jira-story-fr.md : [✅ / ❌ missing (added with retro-spec AMOA exports) / ⚠️ divergent — likely a legitimate project override (custom trame): never overwrite without explicit request]
_template/jira-story-en.md : [✅ / ❌ missing (added with retro-spec AMOA exports) / ⚠️ divergent — likely a legitimate project override (custom trame): never overwrite without explicit request]
_template/spec-doc-fr.md   : [✅ / ❌ missing (added with retro-spec AMOA exports) / ⚠️ divergent — likely a legitimate project override (custom trame): never overwrite without explicit request]
_template/spec-doc-en.md   : [✅ / ❌ missing (added with retro-spec AMOA exports) / ⚠️ divergent — likely a legitimate project override (custom trame): never overwrite without explicit request]
sdd/README.md         : [✅ / ❌ / ⚠️ — from reference/templates/sdd-readme.md]
```

#### 1.4 — SDD agents

Compare each agent found in `reference/agents/` with the project's `.claude/agents/` copy (same divergence classification as step 1 — evolution / customization / translation; never silently flip the language):

```
spec-writer.md      : [✅ present / ❌ missing / ⚠️ divergent]
plan-architect.md   : [✅ / ❌ / ⚠️]
task-decomposer.md  : [✅ / ❌ / ⚠️]
code-reviewer.md    : [✅ / ❌ / ⚠️]
test-generator.md   : [✅ / ❌ / ⚠️ — stack-adapted: compare against THIS skill's reference only]
```

Files present in `.claude/agents/` but absent from the reference are the developer's own agents — ignore them entirely.

### 2. Identify Layers 2 and 3 to preserve

List the files that MUST NOT be touched:

- `.claude/rules/10-code-conventions.md` → Layer 2 (stack conventions)
- `.claude/rules/11-tests-strategy.md` → Layer 2 (rename to the v1.3.0 name allowed, content untouched — see step 0b)
- `.claude/rules/12-quality-gates.md` → Layer 2 (same)
- `.claude/rules/doctrine-conventions.md` → Layer 2
- `.claude/rules/angular-conventions.md` → Layer 2
- `.claude/rules/jpa-conventions.md` → Layer 2
- `.claude/rules/api-contracts.md` → Layer 2
- `.claude/skills/` → Layer 3 (in its entirety)
- `.claude/commands/<stack>-*.md` → Layer 2 (scaffolding commands)
- `.claude/agents/<non-reference>.md` → the developer's own agents

### 3. Produce the upgrade plan

Display in the chat (example — the actual lists come from the audit in step 1):

```
SDD upgrade plan (Layer 1 only)
Reference: <path resolved in step 0> — toolkit v<X.Y.Z if known>
─────────────────────────────────────────
TO ADD:
  + .claude/commands/<missing-command>.md
  + ...

TO RENAME (migration map, content untouched):
  → .claude/rules/<old-name>.md → .claude/rules/<new-name>.md

TO UPDATE:
  ~ .claude/commands/<divergent-command>.md  (reason)
  ~ .claude/rules/<outdated-rule>.md         (reason)
  ~ .claude/sdd/_template/<template>.md      (reason)
  ~ .claude/agents/<divergent-agent>.md      (reason)
  ~ ...

NOT TO TOUCH (Layers 2 and 3 preserved):
  ✓ .claude/rules/10-code-conventions.md
  ✓ .claude/rules/11-tests-strategy.md
  ✓ .claude/rules/12-quality-gates.md
  ✓ .claude/skills/ (in its entirety)
  ✓ .claude/commands/<stack>-*.md

Do you confirm this upgrade?
```

**Wait for explicit confirmation before modifying anything.**

### 4. Apply the upgrade

After confirmation:
- Apply the renames from step 0b (pure rename, content untouched)
- Add the new commands
- Update the identified files (commands, rules, templates, **SDD agents**)
- Fully preserve the **content** of Layer 2 and Layer 3 files (step 0b renames excepted)

At the end of the apply step, **write the deployed version marker**: put the toolkit's `VERSION` value into `.claude/sdd/.sdd-version` (single line, create or overwrite). It lives under `.claude/sdd/` — a framework-owned directory — as a dotfile so it can never collide with a feature folder, and the next `/sdd-upgrade` reads it to apply only the relevant part of the migration map.

### 5. Commit

```
sdd: upgrade SDD core to toolkit v<X.Y.Z>
```

### 6. Announce in the chat

```
✅ SDD Core updated.

Renamed: <old name → new name list, per the step 0b map — or (none)>
Added:   <list of added commands/rules/templates/agents>
Updated: <list of updated files>

Layer 2 (stack conventions): content unchanged ✅ (N file(s) renamed)
Layer 3 (project skills): unchanged ✅
```

## Stop rules

- ❌ **Never audit against this file's embedded checklists alone** — the reference directory resolved in step 0 is the only source of truth; if it cannot be located, stop and ask the user rather than concluding "nothing to upgrade"
- ❌ **Never touch the content** of Layer 2 or Layer 3 files — even if outdated. The only exception is the step 0b rename (filename only, content untouched)
- ❌ **Never rename** the 17 existing universal commands
- ❌ **Never touch** the developer's own agents (`.claude/agents/` files absent from the reference)
- ❌ **Never overwrite** a project's filled-in `01-constitution.md` — only deploy the skeleton where none exists
- ❌ **Never overwrite** `.claude/sdd/README.md` — it is a live feature index; deploy it only where missing, and preserve every feature row if its structure must be rebuilt
- ✅ **Always wait** for explicit confirmation before writing anything
