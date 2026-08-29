---
description: SDD maintenance — updates the framework-owned Layer 1 and the selected-skill-owned Layer 2, preserving the project-owned Layer 3
---

# /sdd-upgrade

**Maintenance command**: bring an existing project's SDD deployment back in line with its owners — **Layer 1 updates from the framework reference, Layer 2 (rules AND stack commands) updates from the selected skill reference, Layer 3 is preserved byte-for-byte** — always preserving project truth before replacing anything (step 2b).

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

- `reference/commands/` → **two owners**: every `sdd-*.md` plus `retro-spec.md` is a **universal command** (framework-owned — audit and upgrade it, step 1.1); **every other command file present in the reference** is a **Layer 2 stack command** (skill-owned — audit and update it, step 1.6). A project command absent from both sets is the project's own — **never touched**. Reference membership decides, never the filename prefix.
- `reference/rules/` → **ownership is decided by the canonical list and by reference membership — never by filename prefix**:
  - the **canonical Layer-1 rules** — `00-sdd-framework.md`, `02-git-conventions.md`, `03-security.md`, `04-code-quality.md` — are framework-owned: audit and upgrade them; after migration the project's copies must equal the reference exactly;
  - **every other rule file present in the reference** is **Layer 2** (owned by the selected skill): audit it and update it from the reference once project truth is preserved (step 2b) — its name may be numbered (`10-…`) or not (`api-contracts.md`); the name decides nothing;
  - a project rule file **absent from the reference** is **Layer 3** (project-owned) — never touched (step 2);
  - a project `01-constitution.md` is a **legacy project-constitution carrier**, handled only by the dedicated migration (step 2c) — it is not part of the final Layer-1 set and is never deployed to new projects.
- `reference/templates/` → all files; they deploy to `.claude/sdd/_template/<name>.md`, except `sdd-readme.md` which deploys to `.claude/sdd/README.md` **only if that file does not exist yet**. `.claude/sdd/README.md` is a **static SDD guide** — live feature state is derived by `/sdd-status` from the feature folders and their frontmatter, never stored in that file. A project still carrying the older framework-generated **dynamic index** schema is migrated in step 4b.
- `reference/agents/` → the 5 SDD agents (`spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer`, `test-generator`); they deploy to `.claude/agents/<name>.md`. `test-generator` is **stack-adapted**: the skill's reference is the correct source for this project — never compare it against another skill's copy. Files in `.claude/agents/` that do not exist in the reference are the developer's own agents — **never touch them**.

**Ownership is not applicability.** Reference membership says who OWNS an artifact — never whether this project must HAVE it. Some skill-owned artifacts are explicitly **conditional** in the selected skill's own installation contract (the deploy list of its `SKILL.md` — e.g. entries marked *(brownfield only)*). Evaluate such a condition with the **same evidence the skill's own mode detection uses** (its Phase 0 greenfield/brownfield test) — never a second definition. The **effective Layer-2 set** = every always-applicable skill-owned rule/command, plus each conditional artifact whose condition is TRUE. Expected presence, additions and the step 4c postconditions apply to the **effective set only**; the raw reference still decides ownership. Per conditional artifact:

- condition **TRUE** + absent from the project → addition to deploy; TRUE + divergent → step 2b triage;
- condition **FALSE** + absent → **expected absence** — not drift, not a missing file, nothing to do;
- condition **FALSE** + present → `CONDITIONAL_LAYER2_PRESENT_NOT_APPLICABLE`: **preserve** the file (it may carry historical or custom content, or the project mode may have changed), report it, and require `USER_DECISION_REQUIRED` before any removal or relocation — never auto-delete;
- condition **indeterminable** from the skill contract and project evidence → preserve the current state (no add, no removal, no replacement), `USER_DECISION_REQUIRED` — never guess.

### 0b. Apply pending file renames (migration map)

The toolkit may have renamed Layer 1/Layer 2 files between versions. Before auditing, **rename** any project file still under an old name (a pure rename: content untouched, customizations preserved).

**The map is applied structurally, never by comparing release numbers**: for each entry, if the old name still exists in the project, rename it; if the old name is absent, there is nothing to do for that entry. `.claude/sdd/.sdd-version` (one line, written by the previous `/sdd-upgrade`) tells you which reference was deployed last — state it in the plan, but let the on-disk names drive the map. Current map:

| Old name (in `.claude/rules/`) | New name |
|---|---|
| `05-constitution.md` | `01-constitution.md` |
| `20-git-conventions.md` | `02-git-conventions.md` |
| `50-security.md` | `03-security.md` |
| `30-tests-strategy.md` | `11-tests-strategy.md` |
| `40-quality-gates.md` | `12-quality-gates.md` |

Renaming per the migration map is a **structural legacy step performed before** the normal Layer-2 ownership/applicability synchronization — a rename is not a content change, and the upgraded Layer 1 commands reference the new names. If both old and new names exist, stop and ask the user which content to keep.

### 1. Audit the existing Layer 1

For every Layer 1 file enumerated in the reference (step 0), compare it with the project's copy: `❌ missing` / `⚠️ divergent` (diff the content) / `✅ present and current`. **A reference file absent from the checklists below is a new addition — audit it all the same.**

When diffing, classify each divergence by nature:

- **Genuine methodology/stack evolution** — new sections, changed behavior → `REPLACE_FROM_FRAMEWORK` (Layer 1) or `REPLACE_FROM_SKILL` (Layer 2)
- **Project truth embedded in an owned file** — content the team added deliberately (branch model, ticket prefixes, project security decisions…) → it does **not** stay in the owned file: it is relocated to its Layer-3 home first (`SAFE_PROJECT_RELOCATION`), then the owned file is replaced. Relocation is automatic **only** when the project-owned boundaries are deterministic, the target has no conflicting content, and preservation can be text-verified — otherwise `USER_DECISION_REQUIRED`, and the source file is not replaced until decided.
- **Translation only** — the project's copy was deployed in another language and the structure maps 1:1 to the reference → no behavioral change. If a whole language flip would result, **ask the user** to choose: keep the project's language (apply only the genuine evolutions, translated) or overwrite with the reference language. Never silently flip the tooling language.

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
02-git-conventions.md : [✅ / ❌ / ⚠️]
03-security.md        : [✅ / ❌ / ⚠️]
04-code-quality.md    : [✅ / ❌ missing (deploy it) / ⚠️]
01-constitution.md    : [absent (nothing to do) / present → LEGACY project-constitution carrier, step 2c migration — never overwrite, never redeploy]
```

#### 1.5 — Layer 2 stack rules (selected skill)

Compare every **non-canonical** rule file of `reference/rules/` **within the effective Layer-2 set** (see *Ownership is not applicability*, step 0) with the project's copy: `✅ identical` / `⚠️ divergent (step 2b triage before any replacement)` / `❌ absent from the project (addition to deploy — only when applicable; a conditional rule whose condition is FALSE is expectedly absent)`. A project rule file absent from the reference is **not** listed here — it is Layer 3 (step 2).

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

#### 1.6 — Layer 2 stack commands (selected skill)

Compare every **non-universal** command file of `reference/commands/` **within the effective Layer-2 set** (same applicability contract as the rules) with the project's `.claude/commands/` copy: `✅ identical` / `⚠️ divergent (step 2b triage before any replacement — a divergence may carry project truth)` / `❌ absent from the project (addition to deploy — only when applicable; a conditional command whose condition is FALSE is expectedly absent)`. A project command absent from the reference is project-owned — never listed here, never touched.

### 2. Identify Layers 2 and 3 to preserve

**Ownership is resolved by one algorithm, never by filename prefix.** For each project rule path R in `.claude/rules/`:

1. R is one of the four canonical Layer-1 files → **framework-owned** (upgraded, step 1.2);
2. else R exists at the same relative path in the selected skill's `reference/rules/` → **Layer 2, skill-owned** (updated, steps 1.5/2b);
3. else → **Layer 3, project-owned**: **NEVER byte-replaced**, never audited against the reference — its absence from the reference is expected ownership, not drift. A numbered project rule (`13-*.md`…) absent from the reference is still Layer 3: the prefix decides nothing. Special case: `01-constitution.md` → legacy carrier, step 2c only.

Also never touched:

- `.claude/skills/` → Layer 3 (in its entirety)
- `.claude/commands/` files absent from both the universal set and the selected skill's `reference/commands/` → the project's own commands
- `.claude/agents/<non-reference>.md` → the developer's own agents

Illustrations of the ownership algorithm (non-exhaustive): `10-code-conventions.md`, `angular-conventions.md`, `api-contracts.md`, `migration-guard.md` are Layer 2 **when the selected skill's reference ships them**; the same names in a project whose skill does not ship them — or any name the reference has never heard of — are Layer 3.

### 2b. Layer triage of the divergences

For **every divergent artifact that is framework-owned or selected-skill-owned, wherever the inventory found it** — Layer-1 rules, Layer-2 rules, Layer-2 stack commands, and any other reference-owned artifact this upgrade compares and may replace — classify **each divergence** with the layer test — *Layer 1: true for every project, whatever the technology. Layer 2: true for the whole stack, whatever the project; a sentence that names a branch, a ticket prefix, a host or a project path is not Layer 2. Layer 3: everything else* — and assign exactly one action:

- **`SAFE_PROJECT_RELOCATION`** — the divergence is project truth living in an owned file → move it **verbatim** (never rewritten, never improved, never translated) to its Layer-3 home: project Git configuration → `project-git-workflow.md` (or the project's existing equivalent Git rule); project security truth → `project-security.md` (or existing equivalent); other project truth in `00`/`04` or a Layer-2 file → the matching project rule. Automatic **only** when the project-owned boundaries are deterministic, the target has no conflicting content, and preservation is text-verified. **No `PROJECT OVERRIDE` block ever remains inside a Layer-1 file**: after migration, Layer 1 equals the framework reference exactly.
- **`REPLACE_FROM_FRAMEWORK` / `REPLACE_FROM_SKILL`** — the divergence is stale owned content fully covered by the current reference → replace, only after proving no project truth is lost (paste the grep on the project's file showing the divergent content is either relocated or genuinely stale).
- **`PRESERVE_PROJECT`** — the file is Layer 3: nothing to triage, nothing to replace.
- **`STRUCTURAL_LEGACY_MIGRATION`** — the step 0b renames and the step 2c constitution migration.
- **`USER_DECISION_REQUIRED`** — implicit or mixed divergence whose boundary is not deterministic → the source file is **not replaced** until the user decides. Never guess; never merge.

Present the triage table (divergence → action → destination → proof for any replacement) **before** the upgrade plan. Nothing is moved, replaced or deleted until the user confirms the plan in step 3.

### 2c. Migrate the legacy project constitution

If `.claude/rules/01-constitution.md` exists in the project:

- **Untouched or empty scaffold** (deterministic evidence: placeholders only, no team-authored principle, `status: draft` with empty principles) → remove the legacy file during the apply step; do **not** create a `project-constitution.md` the team never asked for.
- **Meaningful content, and no `project-constitution.md`** → create `.claude/rules/project-constitution.md` preserving the old content, meaning, order, `status` and ratification metadata **verbatim** — never rewrite the principles, never split them into universal/stack/project automatically. Verify preservation, **then** remove the legacy file.
- **Meaningful content AND an existing `project-constitution.md`** → `USER_DECISION_REQUIRED`: never merge, never overwrite — leave both in place and report.
- **Cannot tell empty from meaningful** → `USER_DECISION_REQUIRED`. Never guess.

### 3. Produce the upgrade plan

Display in the chat (example — the actual lists come from the audit in step 1):

```
SDD upgrade plan (ownership-based: Layer 1 from framework, Layer 2 from selected skill, Layer 3 preserved)
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

OWNERSHIP MIGRATION (steps 2b/2c — every item carries exactly one action):
  → <divergence> → REPLACE_FROM_FRAMEWORK / REPLACE_FROM_SKILL / PRESERVE_PROJECT /
    SAFE_PROJECT_RELOCATION / STRUCTURAL_LEGACY_MIGRATION / USER_DECISION_REQUIRED
    (proof shown for any replacement of divergent content)

NOT TO TOUCH (Layer 3 — ownership algorithm of step 2, never a prefix rule):
  ✓ every .claude/rules/ file absent from the selected skill's reference/rules/
    (project-constitution.md, project-git-workflow.md, any project rule — numbered or not)
  ✓ .claude/skills/ (in its entirety)
  ✓ project commands and agents absent from the framework and selected-skill references

Do you confirm this upgrade?
```

**Wait for explicit confirmation before modifying anything.**

### 4. Apply the upgrade

After confirmation, in this order — **project truth is made safe before anything is replaced**:
1. Apply the renames from step 0b (pure rename, content untouched)
2. Apply the confirmed `SAFE_PROJECT_RELOCATION`s and the step 2c constitution migration — copy project content to its Layer-3 destination and **verify preservation** before any source file is touched
3. Replace the canonical Layer-1 files from the framework reference (`REPLACE_FROM_FRAMEWORK`) — after this step the project's Layer 1 equals the reference exactly
4. Replace/add the Layer-2 files — **rules and stack commands, effective Layer-2 set only** — from the selected skill reference (`REPLACE_FROM_SKILL`), skipping any file with a pending `USER_DECISION_REQUIRED`; a conditional artifact whose condition is FALSE is neither added nor removed
5. Update the toolkit-owned commands, templates and **SDD agents** per their existing ownership contracts
6. Preserve every Layer-3 file byte-for-byte (relocations only ever **add** a new Layer-3 file or append to a confirmed target — never rewrite one)

At the end of the apply step, **write the deployed version marker**: put the toolkit's `VERSION` value into `.claude/sdd/.sdd-version` (single line, create or overwrite). It lives under `.claude/sdd/` — a framework-owned directory — as a dotfile so it can never collide with a feature folder, and the next `/sdd-upgrade` reads it to apply only the relevant part of the migration map.

### 4b. Migrate the legacy `sdd/README.md` dynamic index

If the project's `.claude/sdd/README.md` still follows the older framework-generated **dynamic index** schema (tables `## Features in progress` — `| Feature | Branch | Spec status | Created on |` —, `## Retrospective specs`, and manually synchronized `## Archived features` rows), migrate it:

- replace the **framework-owned dynamic tables and their headings** with the current static guide from `reference/templates/sdd-readme.md`;
- do **not** touch the feature folders, do **not** reconstruct missing rows, do **not** infer statuses — that state was duplicated and is now derived live by `/sdd-status`;
- **preserve any custom project prose** the team added to the file (any section that is not one of the framework-owned tables/headings above);
- if custom content is interleaved with the framework-owned sections so the ownership boundary is ambiguous: **do not overwrite the file** — report "manual review required for `.claude/sdd/README.md`" and leave it unchanged.

### 4c. Post-upgrade ownership verification

After the apply (and the step 4b migration), verify the final ownership state against the same reference resolved in step 0 — never a different one. **Full success** means ALL of:

- every canonical Layer-1 file equals the framework reference exactly (no `PROJECT OVERRIDE` block remains inside Layer 1);
- every Layer-2 path of the **effective Layer-2 set** — rules **and** stack commands — equals the reference; the absence of a conditional skill artifact whose condition is FALSE is **valid**, never a failure;
- every Layer-3 file is byte-identical to its pre-upgrade content (relocation targets excepted — they only gained the relocated content, verified in step 4.2);
- no active legacy `01-constitution.md` remains (removed empty, or migrated to `project-constitution.md` with preservation verified);
- the project constitution, when one existed or was migrated, is preserved with its status and metadata;
- no `USER_DECISION_REQUIRED` item is pending (constitution conflict, ambiguous divergence, ambiguous README ownership from step 4b).

Report every unresolved item honestly, with what is pending and why the framework refuses to decide alone. This verification is recomputed fresh at each upgrade and produces no persistent manifest.

### 5. Commit

Message resolved through the **effective Git policy** (`02-git-conventions.md` § Effective Git policy resolution). Semantic intent: *update the SDD framework/stack configuration to the deployed reference version* (read dynamically — e.g. from the toolkit `VERSION` file). Framework maintenance legitimately has **no ticket**: use the effective policy's no-ticket maintenance default — never invent a fake ticket, never define a command-specific syntax here.

Subject line only — never a `Co-Authored-By` or any tool-generated trailer (see `02-git-conventions.md` § Absolute prohibitions).

### 6. Announce in the chat

Derive the final status from the step 4c verification — never emit an unconditional success. The decision is exhaustive over exactly **three outcomes**:

| Postconditions | User decision pending | Mechanical failure | Result |
|---|---|---|---|
| pass | no | no | ✅ UPDATED |
| incomplete only because of pending decisions | yes | no | ⚠️ UPDATED PARTIALLY |
| fail | no | yes | ❌ UPDATE INCOMPLETE |
| fail | yes | yes | ❌ UPDATE INCOMPLETE (pending decisions reported separately) |

A **mechanical/application failure** is any postcondition failing for a non-decision reason: unresolvable reference, failed copy or Git/file operation, parity not reached after replacement, preservation verification failure, required migrated artifact missing. It always yields ❌, even when user decisions are also pending.

```
✅ SDD Core UPDATED — Layer 1 = framework, Layer 2 = selected skill, Layer 3 preserved.
(or)
⚠️ SDD Core UPDATED PARTIALLY — OWNERSHIP MIGRATION REQUIRES USER DECISION (see step 4c report).
(or)
❌ SDD Core UPDATE INCOMPLETE — <mechanical failure(s)>; fix and re-run /sdd-upgrade. Pending user decisions, if any, are listed separately.

Renamed:    <old name → new name list, per the step 0b map — or (none)>
Relocated:  <project truth moved to its Layer-3 home — or (none)>
Added:      <list of added commands/rules/templates/agents>
Updated:    <list of updated files>
Pending:    <USER_DECISION_REQUIRED items — or (none)>
README:     <static guide already / migrated (step 4b) / ⚠️ manual review required>
Constitution: <none / migrated to project-constitution.md / preserved / ⚠️ decision required>

Layer 3 (project rules, skills, own agents): preserved byte-for-byte ✅
```

## Stop rules

- ❌ **Never audit against this file's embedded checklists alone** — the reference directory resolved in step 0 is the only source of truth; if it cannot be located, stop and ask the user rather than concluding "nothing to upgrade"
- ❌ **Never byte-replace a Layer-3 file** — a project rule absent from the selected skill's reference is project-owned, whatever its name or prefix; relocations only ever **add** to Layer 3, never rewrite it
- ❌ **Never replace a divergent Layer-1 or Layer-2 file before its project truth is preserved and verified** — preservation first, replacement second; a pending `USER_DECISION_REQUIRED` freezes that file
- ❌ **Never classify a divergence "abandon — already covered elsewhere" without pasting the proof** — the grep on the project's actual file, with its raw output. No proof → relocate instead
- ❌ **Never rename** the 17 existing universal commands
- ❌ **Never touch** the developer's own agents (`.claude/agents/` files absent from the reference)
- ❌ **Never merge, rewrite or overwrite constitutions** — a meaningful legacy `01-constitution.md` migrates **verbatim** to `project-constitution.md` (step 2c); if a `project-constitution.md` already exists, both stay in place and the user decides; `01-constitution.md` is never deployed to any project
- ❌ **Never overwrite** `.claude/sdd/README.md` blindly — deploy it only where missing; the one sanctioned rewrite is the step 4b migration of the known framework-owned dynamic-index schema (framework-owned tables replaced, custom project prose preserved, ambiguous ownership → manual review, never a blind overwrite)
- ✅ **Always wait** for explicit confirmation before writing anything
