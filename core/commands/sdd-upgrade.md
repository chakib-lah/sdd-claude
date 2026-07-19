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

### 1. Audit the existing Layer 1

#### 1.1 — Universal commands

Check the presence of each of the 12 universal commands:

```
sdd-start        : [✅ present / ❌ missing / ⚠️ divergent behavior]
sdd-spec         : [...]
sdd-plan         : [...]
sdd-tasks        : [...]
sdd-implement    : [...]
sdd-verify       : [...]
sdd-review       : [...]
sdd-status       : [...]
retro-spec       : [...]
sdd-archive      : [✅ / ❌ missing — new command v1.1]
sdd-mr           : [✅ / ❌ missing — new command v1.1]
sdd-spec-check   : [✅ / ❌ missing — new command v1.1]
sdd-hotfix       : [✅ / ❌ missing — new command v1.1]
sdd-changelog    : [✅ / ❌ missing — new command v1.1]
```

#### 1.2 — Methodology rules

```
00-sdd-framework.md   : [✅ present / ❌ missing / ⚠️ old version]
20-git-conventions.md : [✅ / ❌ / ⚠️]
```

#### 1.3 — Templates

```
_template/spec.md     : [✅ / ❌ / ⚠️ — blocked-by field missing in tasks.md?]
_template/plan.md     : [✅ / ❌ / ⚠️]
_template/tasks.md    : [✅ / ❌ / ⚠️]
_template/notes.md    : [✅ structured / ⚠️ empty template (old version)]
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

Display in the chat:

```
SDD upgrade plan (Layer 1 only)
─────────────────────────────────────────
TO ADD:
  + .claude/commands/sdd-archive.md
  + .claude/commands/sdd-mr.md
  + .claude/commands/sdd-spec-check.md
  + .claude/commands/sdd-hotfix.md
  + .claude/commands/sdd-changelog.md

TO UPDATE:
  ~ .claude/commands/sdd-implement.md  ([P] task strategy)
  ~ .claude/commands/sdd-review.md     (fix+re-review cycle)
  ~ .claude/rules/00-sdd-framework.md  (context recovery section)
  ~ .claude/sdd/_template/notes.md     (structured template)
  ~ .claude/sdd/_template/tasks.md     (blocked-by field)

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
chore(sdd): upgrade SDD core v1.0.0 → v1.1.0
```

### 6. Announce in the chat

```
✅ SDD Core updated.

Added:   sdd-archive, sdd-mr, sdd-spec-check, sdd-hotfix, sdd-changelog
Updated: sdd-implement, sdd-review, 00-sdd-framework, notes.md, tasks.md

Layer 2 (stack conventions): unchanged ✅
Layer 3 (project skills): unchanged ✅
```

## Stop rules

- ❌ **Never touch** Layer 2 or Layer 3 files — even if outdated
- ❌ **Never rename** the 9 existing universal commands
- ✅ **Always wait** for explicit confirmation before writing anything
