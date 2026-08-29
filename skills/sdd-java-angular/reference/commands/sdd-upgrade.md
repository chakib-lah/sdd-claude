---
description: SDD maintenance — updates the common core (Layer 1) without touching the content of Layer 2 or the project skills (Layer 3)
---

# /sdd-upgrade

**Maintenance command**: update the SDD common core (Layer 1 — methodology) in an existing project, without touching the **content** of the code conventions (Layer 2) or the domain skills (Layer 3) — the only Layer 2 touches allowed are the step 0b file rename and the step 2b triage relocations (which only ever **add** displaced content to a Layer 2/3 file, after user confirmation).

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
- `reference/rules/` → **the prefix is the rule**: every `0x-*.md` file is Layer 1 (owned by the toolkit — audit and upgrade it); every `1x-*.md` file and every unnumbered rule file is Layer 2 or 3 — ignore it. Apply the prefix rule to what the reference actually contains, never to a memorized list: a `0x` rule added by a newer toolkit (illustration, non-exhaustive: `04-code-quality.md`) is in scope even though older deployments never had it.
- `reference/templates/` → all files; they deploy to `.claude/sdd/_template/<name>.md`, except `sdd-readme.md` which deploys to `.claude/sdd/README.md` **only if that file does not exist yet**. `.claude/sdd/README.md` is a **static SDD guide** — live feature state is derived by `/sdd-status` from the feature folders and their frontmatter, never stored in that file. A project still carrying the older framework-generated **dynamic index** schema is migrated in step 4b.
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

Compare each Layer 1 rule found in `reference/rules/` (every `0x-*.md` — see scope in step 0) with the project's `.claude/rules/`. A `0x` rule present in the reference but absent from the project is an **addition to deploy**, not a divergence. Illustration (non-exhaustive — the actual list comes from the reference):

```
00-sdd-framework.md   : [✅ present / ❌ missing / ⚠️ old version]
01-constitution.md    : [✅ / ❌ / ⚠️ — never overwrite a filled-in constitution]
02-git-conventions.md : [✅ / ❌ / ⚠️]
03-security.md        : [✅ / ❌ / ⚠️]
04-code-quality.md    : [✅ / ❌ missing (added with the code-quality baseline — deploy it) / ⚠️]
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
sdd/README.md         : [✅ static guide / ❌ missing (deploy from reference/templates/sdd-readme.md) / ⚠️ old dynamic-index schema → step 4b migration]
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

**The prefix is the rule, not a list of names**: in `.claude/rules/`, every `1x-*.md` file and every unnumbered rule file is Layer 2 or 3 and is **NEVER touched** (the step 0b rename excepted). This covers files this checklist has never heard of — a project's `13-*.md` or `migration-guard.md` is preserved by the prefix rule, not by being enumerated here.

Also never touched:

- `.claude/skills/` → Layer 3 (in its entirety)
- `.claude/commands/<stack>-*.md` → Layer 2 (scaffolding commands)
- `.claude/agents/<non-reference>.md` → the developer's own agents

Illustrations of the prefix rule (non-exhaustive): `10-code-conventions.md`, `11-tests-strategy.md`, `12-quality-gates.md`, `doctrine-conventions.md`, `angular-conventions.md`, `jpa-conventions.md`, `api-contracts.md`, `migration-guard.md`.

### 2b. Layer triage of the divergences

For every **Layer 1 file that diverges** from the reference (step 1), classify **each divergence** with the layer test — *Layer 1: true for every project, whatever the technology; a sentence that names a framework, a tool or a command is not Layer 1. Layer 2: true for the whole stack, whatever the project; a sentence that names a branch, a ticket prefix, a host or a project path is not Layer 2. Layer 3: everything else* — and propose a destination:

- **Project-override block** — the divergence is a deliberate project decision on a Layer 1 subject (e.g. a branch-model override sanctioned by `02-git-conventions.md`) → keep it as an explicit override block inside the upgraded file
- **Layer 2 file** — the divergence is stack truth (a tool name, a framework anti-pattern) → move it to the matching `1x-*.md` file
- **New Layer 3 rule file** — the divergence is project truth (hosts, paths, team conventions) → move it to a new unnumbered rule file
- **Abandon — already covered elsewhere** — allowed **only with the proof shown**: run the grep on the PROJECT's actual target file and paste its raw output in the triage. **No proof → no deletion; relocate instead.** A divergence someone once wrote had a reason; the burden of proof is on the deletion, never on the content.

Present the triage table (divergence → classification → destination → proof if abandoned) **before** the upgrade plan. Nothing is moved or deleted until the user confirms the plan in step 3.

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

LAYER TRIAGE (from step 2b, if any Layer 1 file diverged):
  → <divergence> → <destination> (proof shown for any abandon)

NOT TO TOUCH (Layers 2 and 3 preserved — prefix rule: 1x-* and unnumbered):
  ✓ .claude/rules/1x-*.md (e.g. 10-code-conventions, 11-tests-strategy, 12-quality-gates)
  ✓ .claude/rules/<unnumbered>.md (e.g. migration-guard.md)
  ✓ .claude/skills/ (in its entirety)
  ✓ .claude/commands/<stack>-*.md

Do you confirm this upgrade?
```

**Wait for explicit confirmation before modifying anything.**

### 4. Apply the upgrade

After confirmation:
- Apply the renames from step 0b (pure rename, content untouched)
- Add the new commands and the new `0x` rules
- Apply the layer-triage relocations confirmed in step 2b (a relocation copies the content to its destination **before** the Layer 1 file is upgraded — never upgrade first)
- Update the identified files (commands, rules, templates, **SDD agents**)
- Fully preserve the **content** of Layer 2 and Layer 3 files (step 0b renames and step 2b relocation **additions** excepted — relocations only ever add to a Layer 2/3 file, never rewrite it)

At the end of the apply step, **write the deployed version marker**: put the toolkit's `VERSION` value into `.claude/sdd/.sdd-version` (single line, create or overwrite). It lives under `.claude/sdd/` — a framework-owned directory — as a dotfile so it can never collide with a feature folder, and the next `/sdd-upgrade` reads it to apply only the relevant part of the migration map.

### 4b. Migrate the legacy `sdd/README.md` dynamic index

If the project's `.claude/sdd/README.md` still follows the older framework-generated **dynamic index** schema (tables `## Features in progress` — `| Feature | Branch | Spec status | Created on |` —, `## Retrospective specs`, and manually synchronized `## Archived features` rows), migrate it:

- replace the **framework-owned dynamic tables and their headings** with the current static guide from `reference/templates/sdd-readme.md`;
- do **not** touch the feature folders, do **not** reconstruct missing rows, do **not** infer statuses — that state was duplicated and is now derived live by `/sdd-status`;
- **preserve any custom project prose** the team added to the file (any section that is not one of the framework-owned tables/headings above);
- if custom content is interleaved with the framework-owned sections so the ownership boundary is ambiguous: **do not overwrite the file** — report "manual review required for `.claude/sdd/README.md`" and leave it unchanged.

### 4c. Post-upgrade residual-divergence report

After the apply (and the step 4b migration), answer the question an upgrade used to leave open: **"what still differs from the reference?"** Using the **same reference resolved in step 0** — never a different one —, recompute the Layer-1 comparison and classify **every residual divergence**. This step **reports only**: it never moves, deletes, creates or rewrites anything, and produces no persistent manifest — it is recomputed fresh at each upgrade.

Every residual receives exactly one classification:

| Classification | Meaning | Suggested action |
|---|---|---|
| `DECLARED_PROJECT_OVERRIDE` | explicit, sanctioned project override of a Layer 1 subject | keep if intentional |
| `IMPLICIT_PROJECT_OVERRIDE` | project decision on a Layer 1 subject, not declared at every divergent site | candidate for explicit declaration / consolidation |
| `MISLAYERED_STACK_TRUTH` | stack/tool/framework truth still living in a Layer 1 file | candidate relocation to the matching Layer 2 file |
| `MISLAYERED_PROJECT_TRUTH` | project/path/host/team/application truth still living in a Layer 1 file (e.g. a project's authentication architecture inside `03-security.md`) | candidate relocation to a Layer 3 rule |
| `ALLOWED_TEXTUAL_VARIANT` | semantically equivalent textual/localized variant the step 1 classification explicitly recognizes (translation-only deployments) | none |
| `UNEXPLAINED_DIVERGENCE` | cannot be justified from any known project or framework rule | manual investigation |

For each residual, report: **file · divergent subject (concise) · classification · reason · suggested destination/action · user confirmation required (yes/no)**.

**Not residuals** — normal, expected project state, never reported as drift: a filled/ratified `01-constitution.md`; project-own template overrides already classified as such in step 1.3; every Layer 2/3 file (prefix rule, step 2); the developer's own agents; the stack-adapted `test-generator`; a `sdd/README.md` already migrated to the static guide.

### 5. Commit

```
sdd: upgrade SDD core to toolkit v<X.Y.Z>
```

Subject line only — never a `Co-Authored-By` or any tool-generated trailer (see `02-git-conventions.md` § Absolute prohibitions).

### 6. Announce in the chat

Derive the final status from the step 4c report **and** the step 4b outcome — never emit an unconditional success. The decision is exhaustive:

- **Benign residual classes**: `DECLARED_PROJECT_OVERRIDE`, `ALLOWED_TEXTUAL_VARIANT`.
- **Warning residual classes**: `IMPLICIT_PROJECT_OVERRIDE`, `MISLAYERED_STACK_TRUTH`, `MISLAYERED_PROJECT_TRUTH`, `UNEXPLAINED_DIVERGENCE`.
- **README manual review pending** (step 4b reported "manual review required") is a separate outcome flag — not a seventh residual class.

**✅ UPDATED** if and only if no README manual review is pending AND (the residual set is empty OR every residual belongs to a benign class). **⚠️ UPDATED WITH RESIDUALS** if and only if a README manual review is pending OR at least one residual belongs to a warning class. Mixed sets are deterministic: benign + any warning residual → ⚠️; benign-only (in any combination) → ✅; no residual but README review pending → ⚠️.

```
✅ SDD Core UPDATED — benign residuals only (or none), no pending README review.
(or)
⚠️ SDD Core UPDATED WITH RESIDUALS — review the residual-divergence table (step 4c) and/or the pending README manual review (step 4b).

Renamed: <old name → new name list, per the step 0b map — or (none)>
Added:   <list of added commands/rules/templates/agents>
Updated: <list of updated files>
Residuals: <count by classification — or (none)>
README:    <static guide already / migrated (step 4b) / ⚠️ manual review required>

Layer 2 (stack conventions): content unchanged ✅ (N file(s) renamed)
Layer 3 (project skills): unchanged ✅
```

## Stop rules

- ❌ **Never audit against this file's embedded checklists alone** — the reference directory resolved in step 0 is the only source of truth; if it cannot be located, stop and ask the user rather than concluding "nothing to upgrade"
- ❌ **Never touch the content** of Layer 2 or Layer 3 files — even if outdated. The only exceptions are the step 0b rename (filename only, content untouched) and the step 2b triage relocations (additions only, confirmed by the user)
- ❌ **Never classify a divergence "abandon — already covered elsewhere" without pasting the proof** — the grep on the project's actual file, with its raw output. No proof → relocate instead
- ❌ **Never rename** the 17 existing universal commands
- ❌ **Never touch** the developer's own agents (`.claude/agents/` files absent from the reference)
- ❌ **Never overwrite** a project's filled-in `01-constitution.md` — only deploy the skeleton where none exists
- ❌ **Never overwrite** `.claude/sdd/README.md` blindly — deploy it only where missing; the one sanctioned rewrite is the step 4b migration of the known framework-owned dynamic-index schema (framework-owned tables replaced, custom project prose preserved, ambiguous ownership → manual review, never a blind overwrite)
- ✅ **Always wait** for explicit confirmation before writing anything
