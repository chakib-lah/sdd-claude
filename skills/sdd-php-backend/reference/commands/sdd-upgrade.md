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
  - the **canonical Layer-1 rules** — `00-sdd-framework.md`, `01-git-conventions.md`, `02-security.md`, `03-code-quality.md` — are framework-owned: audit and upgrade them; after migration the project's copies must equal the reference exactly;
  - **every other rule file present in the reference** is **Layer 2** (owned by the selected skill): audit it and update it from the reference once project truth is preserved (step 2b) — canonical Layer-2 rules carry their functional-decade name (`10-…`, `30-…`, `50-…`…), but the numeric prefix is visual classification only: reference membership decides ownership, never the name;
  - a project rule file **absent from the reference** is **Layer 3** (project-owned) — never touched (step 2);
  - a project `01-constitution.md` **or `05-constitution.md`** is a **legacy constitution carrier**, handled only by the dedicated migration (step 2c) — neither is part of the final Layer-1 set, neither is ever deployed to new projects, and neither is ever renamed into another slot.
- `reference/templates/` → all files; they deploy to `.claude/sdd/_template/<name>.md`, except `sdd-readme.md` which deploys to `.claude/sdd/README.md` **only if that file does not exist yet**. `.claude/sdd/README.md` is a **static SDD guide** — live feature state is derived by `/sdd-status` from the feature folders and their frontmatter, never stored in that file. A project still carrying the older framework-generated **dynamic index** schema is migrated in step 4b.
- `reference/agents/` → the 5 SDD agents (`spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer`, `test-generator`); they deploy to `.claude/agents/<name>.md`. `test-generator` is **stack-adapted**: the skill's reference is the correct source for this project — never compare it against another skill's copy. Files in `.claude/agents/` that do not exist in the reference are the developer's own agents — **never touch them**.

**Ownership is not applicability.** Reference membership says who OWNS an artifact — never whether this project must HAVE it. Some skill-owned artifacts are explicitly **conditional** in the selected skill's own installation contract (the deploy list of its `SKILL.md` — e.g. entries marked *(brownfield only)*). Evaluate such a condition with the **same evidence the skill's own mode detection uses** (its Phase 0 greenfield/brownfield test) — never a second definition. The **effective Layer-2 set** = every always-applicable skill-owned rule/command, plus each conditional artifact whose condition is TRUE. Expected presence, additions and the step 4c postconditions apply to the **effective set only**; the raw reference still decides ownership. Per conditional artifact:

- condition **TRUE** + absent from the project → addition to deploy; TRUE + divergent → step 2b triage;
- condition **FALSE** + absent → **expected absence** — not drift, not a missing file, nothing to do;
- condition **FALSE** + present → `CONDITIONAL_LAYER2_PRESENT_NOT_APPLICABLE`: **preserve** the file (it may carry historical or custom content, or the project mode may have changed), report it, and require `USER_DECISION_REQUIRED` before any removal or relocation — never auto-delete;
- condition **indeterminable** from the skill contract and project evidence → preserve the current state (no add, no removal, no replacement), `USER_DECISION_REQUIRED` — never guess.

### 0b. Plan pending file renames (migration map)

The toolkit may have renamed Layer 1/Layer 2 files between versions. **This step is WRITE-FREE**: before any write, **detect and plan** — enumerate every project file still under an old name and derive the pending renames from the map below. Nothing is renamed, removed or overwritten here; every write happens in the ordered application phase (step 4), after the legacy constitution is resolved and project truth is preserved and verified.

**The map is evaluated structurally, never by comparing release numbers**: for each entry, if the old name still exists in the project, a rename is **planned** (applied in step 4, as a pure rename: content untouched, customizations preserved); if the old name is absent, there is nothing to plan for that entry. `.claude/sdd/.sdd-version` (one line, written by the previous `/sdd-upgrade`) tells you which reference was deployed last — state it in the plan, but let the on-disk names drive the map. Current map:

| Old name (in `.claude/rules/`) | New name |
|---|---|
| `20-git-conventions.md` | `01-git-conventions.md` |
| `02-git-conventions.md` | `01-git-conventions.md` |
| `50-security.md` | `02-security.md` |
| `03-security.md` | `02-security.md` |
| `04-code-quality.md` | `03-code-quality.md` |
| `30-tests-strategy.md` | `11-tests-strategy.md` |
| `40-quality-gates.md` | `12-quality-gates.md` |

**Layer-2 canonical functional decades — selected-skill-scoped entries:**

| Old name (in `.claude/rules/`) | New name |
|---|---|
| `node-conventions.md` | `20-node-conventions.md` |
| `doctrine-conventions.md` | `30-doctrine-conventions.md` |
| `jpa-conventions.md` | `30-jpa-conventions.md` |
| `angular-conventions.md` | `40-angular-conventions.md` |
| `api-contracts.md` | `50-api-contracts.md` |
| `shared-types.md` | `51-shared-types.md` |
| `refactoring-guard.md` | `60-refactoring-guard.md` |
| `legacy-rules.md` | `61-legacy-rules.md` |
| `migration-guard.md` | `62-migration-guard.md` |

**Layer-2 entries are selected-skill-scoped.** A Layer-2 entry applies **only when the selected skill's reference ships the new canonical artifact** (the logical artifact belongs to this skill's Layer-2 set). When it does, a project file under the old name is a **historical Layer-2 artifact of that skill — never Layer 3**, whatever its current bytes: an older framework revision of the artifact is still Layer 2, and hash mismatch with the current reference proves nothing about ownership. When it does not (e.g. `angular-conventions.md` in a project whose selected skill is `sdd-php-backend`), the entry is **ignored for this project**: the file is Layer 3 — never renamed, never path-repaired through this map, never classified as historical Layer 2 on basename alone. Conditional artifacts (e.g. a brownfield-only `62-migration-guard.md`) keep the *Ownership is not applicability* contract unchanged: with condition FALSE, an old-named present file follows `CONDITIONAL_LAYER2_PRESENT_NOT_APPLICABLE` — preserved, reported, `USER_DECISION_REQUIRED` before any removal **or relocation, including this rename** — and the new canonical file is never force-installed.

**`05-constitution.md` is deliberately NOT in this map**: like `01-constitution.md`, it is a **legacy constitution carrier** (in `.claude/rules/`), handled **directly** by the step 2c constitution migration — it never passes through an intermediate structural rename, and the old `05 → 01 → project-constitution` route no longer exists.

**Slot-01 order — blocking.** Planned entries that rename a Git rule into the `01` slot are applied (step 4) **only after** every legacy constitution carrier (`01-constitution.md`, `05-constitution.md`) has been safely resolved by the step 2c migration (removed if an empty scaffold, migrated verbatim to `project-constitution.md` if meaningful, `USER_DECISION_REQUIRED` on conflict or ambiguity). While that resolution is pending, the project's old Git rule path stays in place untouched — the outcome is then at best ⚠️ partial, never a destructive reuse of the `01` slot.

**Old and new path both present — the ONE coexistence rule** (an old `02-git-conventions.md` next to a new `01-git-conventions.md`, and the equivalent security/code-quality pairs). Never pick or delete automatically, and never unconditionally stop either — classify:

- **redundancy proven** (the old path is byte-equal to the current canonical state, or its every divergence is already preserved with proof) → safe automatic convergence: remove the redundant old artifact in step 4, after verification;
- **deterministic project truth in the old path** → preserve it first (`SAFE_PROJECT_RELOCATION`), verify, then converge;
- **conflict or ambiguity** (redundancy unprovable, truth not safely isolable) → `USER_DECISION_REQUIRED`: preserve both, no destructive action.

The planned renames are a **structural legacy step applied before** the normal Layer-2 ownership/applicability synchronization but **after** constitution resolution and project-truth preservation — a rename is not a content change, and the upgraded Layer 1 commands reference the new names.

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
01-git-conventions.md : [✅ / ❌ / ⚠️]
02-security.md        : [✅ / ❌ / ⚠️]
03-code-quality.md    : [✅ / ❌ missing (deploy it) / ⚠️]
01-constitution.md / 05-constitution.md : [absent (nothing to do) / present → LEGACY constitution carrier(s), step 2c migration — never overwrite, never redeploy, never renamed into another slot]
```

Legacy Layer-1 path shapes are detected **structurally, never by release number**: an old `02-git-conventions.md` (with no `01-git-conventions.md`), an old `03-security.md` (no `02-security.md`) or an old `04-code-quality.md` (no `03-code-quality.md`) is a legacy path — it goes through the normal divergence classification and step 2b preservation-first triage **before** the canonical file is installed and the old path removed. A blind `mv` over a divergent project file is never performed.

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
3. else R is a **known historical canonical alias** (step 0b map, selected-skill-scoped) of a Layer-2 artifact the selected skill ships → **historical Layer 2** (`STRUCTURAL_LEGACY_MIGRATION`: convergence planned in step 0b, applied in step 4.4 under the ONE coexistence rule and the conditional-artifact contract) — never Layer 3;
4. else → **Layer 3, project-owned**: **NEVER byte-replaced**, never audited against the reference — its absence from the reference is expected ownership, not drift. A numbered project rule (`13-*.md`…) absent from the reference is still Layer 3: the prefix decides nothing. Special case: `01-constitution.md` and `05-constitution.md` → legacy constitution carriers, step 2c only.

Also never touched:

- `.claude/skills/` → Layer 3 (in its entirety)
- `.claude/commands/` files absent from both the universal set and the selected skill's `reference/commands/` → the project's own commands
- `.claude/agents/<non-reference>.md` → the developer's own agents

Illustrations of the ownership algorithm (non-exhaustive): `10-code-conventions.md`, `40-angular-conventions.md`, `50-api-contracts.md`, `62-migration-guard.md` are Layer 2 **when the selected skill's reference ships them**; the same names in a project whose skill does not ship them — or any name the reference has never heard of — are Layer 3.

### 2b. Layer triage of the divergences

For **every divergent artifact that is framework-owned or selected-skill-owned, wherever the inventory found it** — Layer-1 rules, Layer-2 rules, Layer-2 stack commands, and any other reference-owned artifact this upgrade compares and may replace — classify **each divergence** with the layer test — *Layer 1: true for every project, whatever the technology. Layer 2: true for the whole stack, whatever the project; a sentence that names a branch, a ticket prefix, a host or a project path is not Layer 2. Layer 3: everything else* — and assign exactly one action:

- **`SAFE_PROJECT_RELOCATION`** — the divergence is project truth living in an owned file → move it **verbatim** (never rewritten, never improved, never translated) to its Layer-3 home: project Git configuration → `project-git-workflow.md` (or the project's existing equivalent Git rule); project security truth → `project-security.md` (or existing equivalent); other project truth in `00`/`04` or a Layer-2 file → the matching project rule. Automatic **only** when the project-owned boundaries are deterministic, the target has no conflicting content, and preservation is text-verified. **No `PROJECT OVERRIDE` block ever remains inside a Layer-1 file**: after migration, Layer 1 equals the framework reference exactly.
- **`REPLACE_FROM_FRAMEWORK` / `REPLACE_FROM_SKILL`** — the divergence is stale owned content fully covered by the current reference → replace, only after proving no project truth is lost (paste the grep on the project's file showing the divergent content is either relocated or genuinely stale).
- **`PRESERVE_PROJECT`** — the file is Layer 3: nothing to triage, nothing to replace.
- **`STRUCTURAL_LEGACY_MIGRATION`** — the renames planned by the step 0b map and the step 2c constitution migration (both applied only in the ordered step 4 phases).
- **`USER_DECISION_REQUIRED`** — implicit or mixed divergence whose boundary is not deterministic → the source file is **not replaced** until the user decides. Never guess; never merge.

Present the triage table (divergence → action → destination → proof for any replacement) **before** the upgrade plan. Nothing is moved, replaced or deleted until the user confirms the plan in step 3.

### 2c. Legacy constitution carrier decision model

The **legacy constitution carriers** are `01-constitution.md` and `05-constitution.md` (in `.claude/rules/`). Both enter this model **directly** — neither ever passes through an intermediate structural rename. This block is the **single normative policy** for legacy constitutions: every other mention of these carriers in this command is a reference to it, never an independent rule.

**Classification.** Classify each carrier as exactly one of `ABSENT` / `PROVEN_EMPTY_SCAFFOLD` (deterministic evidence: placeholders only, no team-authored principle, `status: draft` with empty principles) / `MEANINGFUL` / `AMBIGUOUS` (whenever the empty-vs-meaningful call cannot be made safely — never guess). Let **P** = a `project-constitution.md` already exists; derive `ambiguous_count`, `meaningful_count`, `empty_count` over the two carriers. **Deterministic equivalence** of two meaningful carriers means **exact content equality (byte-identical)** — never inferred from titles, principle counts, similar wording, status, dates or semantic judgment; anything short of exact equality is `NOT_PROVEN_EQUIVALENT`.

**Decision — the predicates are mutually exclusive and exhaustive; every state matches exactly one rule:**

- **D1** — `ambiguous_count > 0` → `USER_DECISION_REQUIRED`: preserve every existing carrier and any existing `project-constitution.md`; no copy, no merge, no removal, no destructive constitution action.
- **D2** — `ambiguous_count = 0` AND `P = YES` AND `meaningful_count > 0` → `USER_DECISION_REQUIRED`: preserve `project-constitution.md` and ALL carriers; no automatic overwrite, merge, deletion or reconciliation. *(This rule owns every meaningful-content state when a project constitution exists — including "one empty + one meaningful": the empty scaffold is NOT removed automatically here, the whole state waits for the user.)*
- **D3** — `ambiguous_count = 0` AND `P = YES` AND `meaningful_count = 0` AND `empty_count > 0` → keep `project-constitution.md` unchanged; safely remove only the proven-empty scaffolds; create nothing.
- **D4** — `ambiguous_count = 0` AND `P = YES` AND `meaningful_count = 0` AND `empty_count = 0` → no-op.
- **D5** — `ambiguous_count = 0` AND `P = NO` AND `meaningful_count = 0` AND `empty_count > 0` → safely remove the proven-empty scaffolds; do **not** create a `project-constitution.md`.
- **D6** — `ambiguous_count = 0` AND `P = NO` AND `meaningful_count = 0` AND `empty_count = 0` → no-op.
- **D7** — `ambiguous_count = 0` AND `P = NO` AND `meaningful_count = 1` → the unique meaningful carrier is the source: copy it **VERBATIM** to `project-constitution.md` (principles, ordering, `status` draft/ratified, ratification metadata/date, project context — never rewrite, never split into universal/stack/project); verify preservation against the source; only after successful verification remove the meaningful source and safely remove the other carrier if proven empty. A verification failure is `❌ UPDATE INCOMPLETE` — no destructive cleanup.
- **D8** — `ambiguous_count = 0` AND `P = NO` AND `meaningful_count = 2` AND equivalence `PROVEN` → preserve the constitution **once** (source chosen deterministically: `01-constitution.md` first, then `05-constitution.md` — legitimate only because exact equivalence is proven); verify the resulting `project-constitution.md` against **both** sources; remove both carriers only after that double verification. No semantic merge.
- **D9** — `ambiguous_count = 0` AND `P = NO` AND `meaningful_count = 2` AND equivalence `NOT_PROVEN` → `USER_DECISION_REQUIRED`: preserve both, no merge, no automatic choice, no deletion.

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

After confirmation, in this order — **nothing structural is written before preservation is verified**:
1. **Execute the step 2c decision model's resulting action** for the legacy constitution carriers (`01-constitution.md`, `05-constitution.md`) — the safe removals, verbatim migration and verifications exactly as the matched D-rule prescribes; a `USER_DECISION_REQUIRED` outcome (D1/D2/D9) leaves everything in place and freezes every slot-01 planned rename
2. **Apply the confirmed `SAFE_PROJECT_RELOCATION`s** — copy project content to its Layer-3 destination **before any source file is touched**
3. **Verify preservation** (constitution + relocations): any mechanical verification failure here is `❌ UPDATE INCOMPLETE` — do **not** continue to any destructive step
4. **Apply the planned structural renames/convergence from the step 0b map** (pure renames, content untouched; slot-01 entries only if step 1 resolved the constitution; coexisting old/new pairs handled by the ONE coexistence rule — a proven-redundant old path is removed only after verification)
5. Replace the canonical Layer-1 files from the framework reference (`REPLACE_FROM_FRAMEWORK`) — after this step the project's Layer 1 equals the reference exactly
6. Replace/add the Layer-2 files — **rules and stack commands, effective Layer-2 set only** — from the selected skill reference (`REPLACE_FROM_SKILL`), skipping any file with a pending `USER_DECISION_REQUIRED`; a conditional artifact whose condition is FALSE is neither added nor removed
7. Update the toolkit-owned commands, templates and **SDD agents** per their existing ownership contracts
8. **Repair dangling canonical references** in eligible preserved active artifacts — see *Path-only canonical reference repair* below; this phase runs **only after** the new canonical paths exist and never before preservation verification
9. Preserve every Layer-3 file byte-for-byte (relocations only ever **add** a new Layer-3 file or append to a confirmed target; the **sole sanctioned mutation** of a preserved file is the path-only canonical reference repair of step 8 — never a rewrite)

#### Path-only canonical reference repair

After structural convergence, an eligible **active** preserved artifact may still reference an OLD canonical Layer-1 filename. Content ownership (frozen Layer 2, `PRESERVE_PROJECT`, Layer 3, `USER_DECISION_REQUIRED`) forbids replacing the file's content — it does **not** license keeping a dangling pointer to a canonical framework path. Content ownership ≠ canonical reference validity. This repair changes **only** a proven canonical path token, and nothing else.

- **Map — one source of truth**: the repair reuses the step 0b structural migration map — its canonical Layer-1 entries (`02-git-conventions.md → 01-git-conventions.md`, `03-security.md → 02-security.md`, `04-code-quality.md → 03-code-quality.md`) **plus its selected-skill-scoped Layer-2 entries**, each eligible only when the selected skill ships the new canonical artifact (the step 0b scoping rule): an alias of an artifact this skill does not own is **never** repaired — no basename-only, fuzzy or cross-skill replacement. The legacy constitution carriers (`01-constitution.md`, `05-constitution.md`) are **never** path-only aliases: they belong exclusively to the step 2c decision model.
- **Eligible artifacts** — ACTIVE textual artifacts that legitimately survived without replacement: preserved/frozen Layer-2 rules and stack commands, Layer-3 project rules, the project's own active commands, agents and skills, and other active project-owned operational artifacts the SDD workflow consumes. Not every file under `.claude/` is active.
- **Excluded — historical feature artifacts**: `.claude/sdd/<feature>/spec.md`, `tasks.md`, `notes.md`, archived features and retrospective records are project history — their content is **never** rewritten because canonical filenames later changed. (`.claude/sdd/README.md` and `_template/**` are active framework artifacts, not history, and keep their own sync rules.)
- **Excluded — reference-owned installs**: an artifact just installed `REPLACE_FROM_FRAMEWORK` or `REPLACE_FROM_SKILL` must equal its reference; a stale canonical path inside such a copy is a **`SOURCE_REFERENCE_DEFECT`** → `❌ UPDATE INCOMPLETE` — never patch the project copy locally to hide a source problem.
- **An occurrence is auto-repaired only when ALL hold**: the file is eligible; the occurrence is an **exact old canonical filename/path token** of the map (the bare filename `03-security.md`, its `rules/`-prefixed or fully `.claude/rules/`-prefixed form, or an equivalent unambiguous Markdown path form) — never an arbitrary substring (`my03-security.md.bak`, `103-security.md`, `example-03-security.md` never match); the mapping is deterministic 1 → 1; the OLD canonical target no longer exists and the NEW one exists (structural convergence completed successfully); the change is exactly old token → new token. When the context does not deterministically prove an active reference (e.g. prose recalling a legacy filename), **preserve it** and report it as `AMBIGUOUS_CANONICAL_PATH_MENTION` — never guess.
- **Byte-preservation guarantee**: snapshot the file first; after repair, verify that reverting only the substituted token(s) reconstructs the original byte-for-byte — whitespace, line endings, headings, punctuation, wording, examples, stack facts, code, ordering and metadata are untouched. Verification failure → restore the original and `❌ UPDATE INCOMPLETE`, no destructive continuation.
- **Multiple occurrences** in one file are each repaired independently under the same predicates.
- **Decisions unchanged**: a repaired file keeps its classification — a frozen Layer-2 file remains `USER_DECISION_REQUIRED`; this repair never turns ⚠️ into ✅ while any unrelated ownership/content decision is pending; if preservation verification or structural convergence failed, this phase does not run at all.

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
- every Layer-3 file is byte-identical to its pre-upgrade content (two sanctioned exceptions: relocation targets, which only gained the relocated content verified in step 4.2, and the path-only canonical reference repairs of step 4.8, byte-verified token substitutions);
- no active legacy constitution carrier remains — neither `01-constitution.md` nor `05-constitution.md` (removed empty, or migrated to `project-constitution.md` with preservation verified);
- the project constitution, when one existed or was migrated, is preserved with its status and metadata;
- no `USER_DECISION_REQUIRED` item is pending (constitution conflict, ambiguous divergence, ambiguous README ownership from step 4b);
- no eligible preserved active artifact keeps a dangling old canonical Layer-1 reference (step 4.8 applied; `AMBIGUOUS_CANONICAL_PATH_MENTION`s are reported, never guessed, and do not block by themselves).

Report every unresolved item honestly, with what is pending and why the framework refuses to decide alone. This verification is recomputed fresh at each upgrade and produces no persistent manifest.

### 5. Commit

Message resolved through the **effective Git policy** (`01-git-conventions.md` § Effective Git policy resolution). Semantic intent: *update the SDD framework/stack configuration to the deployed reference version* (read dynamically — e.g. from the toolkit `VERSION` file). Framework maintenance legitimately has **no ticket**: use the effective policy's no-ticket maintenance default — never invent a fake ticket, never define a command-specific syntax here.

Subject line only — never a `Co-Authored-By` or any tool-generated trailer (see `01-git-conventions.md` § Absolute prohibitions).

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
- ❌ **Never merge, rewrite or overwrite constitutions** — every legacy-constitution action follows the step 2c decision model (D1–D9) and nothing else; no carrier is ever deployed to any project nor renamed into another slot
- ❌ **Never overwrite** `.claude/sdd/README.md` blindly — deploy it only where missing; the one sanctioned rewrite is the step 4b migration of the known framework-owned dynamic-index schema (framework-owned tables replaced, custom project prose preserved, ambiguous ownership → manual review, never a blind overwrite)
- ✅ **Always wait** for explicit confirmation before writing anything
