---
name: sdd-php-backend
description: Generates a Spec-Driven Development framework for a PHP backend project WITHOUT a framework (Symfony, Laravel, etc.). Use this skill when the user requests a SDD framework, .claude/ scaffold, or process tooling for a project that is pure PHP, legacy PHP, procedural PHP, OOP PHP without framework, PHP scripts, home-grown APIs, or PHP migration projects. Triggers include "generate the SDD framework", "install SDD", "setup SDD", "scaffold SDD", "create SDD framework", "génère le framework SDD", "installe SDD" when applied to a PHP-only project (no Symfony, no Laravel detected). Detects brownfield/greenfield mode and adapts. Adds refactoring-guard and legacy-rules for brownfield migrations.
license: MIT
---

# SDD Framework — Pure PHP Backend

This skill installs a complete Spec-Driven Development framework into a PHP project (without framework) by deploying files from `reference/` into the project's `.claude/` directory.

## When to use this skill

Use when:
- The user asks to generate / install / scaffold a SDD framework
- The project is pure PHP (no Symfony, no Laravel, no major framework detected)
- The project might be legacy procedural, OOP without framework, scripts, or in-progress migration

Do NOT use when:
- The project uses Symfony → use `sdd-php-symfony` skill instead
- The project uses Symfony + Angular → use `sdd-symfony-angular` skill instead
- The project uses Laravel, Slim, Phalcon, or another PHP framework → no specific skill yet, fall back to manual setup

## Process

### Phase 0 — Detect mode

Inspect the project root:

- **Greenfield**: no `index.php`, no `src/`, no significant PHP files, no `vendor/`
- **Brownfield**: existing PHP code, possibly without Composer/autoloader

Detect estimated project type:
- Legacy procedural (scripts, includes, globals)
- OOP without framework (classes, possibly with namespaces)
- In-progress migration (partially modernized)

Announce in chat:

```
Detected mode: [GREENFIELD / BROWNFIELD]
Estimated type: [legacy procedural / OOP without framework / in-progress migration]
Reason: [observations]
```

### Phase 1 — Discovery (brownfield only)

**Independent evidence dimensions — never collapse them.** For every discovered capability, establish separately: **(A) configuration/capability** — is the mechanism configured/enabled in the project's configuration? **(B) materialized state** — does a generated artifact currently exist in this workspace? **(C) tracked state** — is that artifact versioned in source control? **(D) workflow** — how/where is it produced (local command, CI, build, on demand, external)? **(E) durable human policy** — what does the team require? Never infer one dimension solely from another unless the technology's canonical semantics make the implication necessarily valid: an absent generated artifact never proves the capability is unconfigured (it may be produced in CI or on demand), and a present artifact never by itself proves current configuration or team policy. A dimension that cannot be established from current evidence is reported as **unknown / not yet established** — never guessed.

Analyze and report on:

**Stack and environment**
- PHP version (from `phpinfo`, `.php-version`, or deduction from syntax)
- Composer presence (`composer.json`)
- Autoloader pattern (PSR-4, PSR-0, manual require, none)
- Database access (PDO direct, MySQLi, custom wrapper, custom ORM)

**Architecture**
- Entry point (`index.php`, custom routing, htaccess rewrite)
- Code organization (procedural, classes without namespace, namespaced OOP)
- Error handling
- Sessions / Auth

**Technical debt**
- Files > 500 lines (God files)
- Free-standing functions count estimate
- Inline SQL in business logic
- Test presence (PHPUnit, manual tests, none)
- Debug leftovers (`var_dump`, `die`, etc.)

**Conventions observed**
- File naming (CamelCase, snake_case, mixed)
- Function/method naming
- Namespaces if any

Then ask the user the 5 brownfield clarification questions:
1. Solo or team maintained?
2. Goal to introduce Composer + PSR-4 if not yet?
3. Critical modules NOT to break?
4. Tolerance for breaking changes?
5. Existing documentation to integrate?

For greenfield, ask the 11 greenfield questions about architecture, conventions, environment.

### Phase 2 — Propose structure

**Final Layer-3 sanitization gate — mandatory before displaying any `project-*` candidate.** A raw discovery result is never a final Layer-3 candidate: after discovery and the developer's clarifications, pass **every clause** of every proposed `project-*` rule through this gate, in order:

1. already owned by a universal Layer-1 invariant → **remove it** (never restate universal policy for emphasis);
2. already owned by an applicable selected-skill Layer-2 contract → **remove it** (Layer 3 specializes — it never duplicates or negates Layer 2);
3. objective technical state rediscoverable from canonical project sources (versions, paths, task names, build/test wiring, generated-artifact locations, provider configuration, architecture merely observed from the code, CI/lint/formatter state, lock-artifact presence…) → **remove it from persistence**; it stays discover-on-demand state;
4. gap / debt / migration state / current limitation / defect observation → **report it as a follow-up** — never desired Layer-3 policy;
5. a remaining durable clause under the wrong `project-*` subject → **relocate** it to its established owner, or **split** the candidate when several durable subjects coexist (Git workflow ≠ security/data policy ≠ architecture ≠ testing ≠ frozen migration decisions ≠ working language — a frozen migration decision never lands in a testing rule merely because tests protect the behavior);
6. the remaining clause is a durable human/team-owned project decision → **keep it** as Layer 3;
7. nothing left after steps 1–6 → **do not create** that `project-*` file.

The gate removes only what steps 1–4 prove: a durable human policy — including one already written in `CLAUDE.md`, an ADR or team documentation — always survives it.

**Final proposal materialization — render only the normalized result.** The gate runs on the **actual candidate text about to be rendered**, never only on the discovery findings, and the sequence is fixed: discovery facts → atomic semantic claims → ownership and Class A–E disposition → architecturally valid developer choices only → developer decisions → final normalization → final consistency validation → immutable `APPROVED_LAYER3_RECORDS` at approval → mechanical rendering → fidelity comparison against those same records; semantic content never crosses a pipeline stage implicitly. A raw or intermediate candidate set is never displayed. Materialize the result as one disposition record per clause:

- **One final disposition per clause** — exactly one of `KEPT` / `REMOVED_L1` / `REMOVED_L2` / `REDISCOVER_ON_DEMAND` / `FOLLOW_UP` / `RELOCATED` / `DROPPED_EMPTY_PARENT`. The kept candidates, the removed-by-gate summary and the follow-up/gap list are all **derived from that single record** — never composed independently — so the same semantic clause can never appear as both kept and removed.
- **Atomic semantic claims** — a candidate is split **before ownership and disposition are assigned** whenever it combines several subjects (e.g. a commit-structure rule that also fixes the writing language — one owner per resulting clause) or several independently meaningful assertions that could receive different dispositions: **one independently meaningful assertion = one disposition**. Durable policy and its attached rediscoverable evidence (current counts, file paths, task names, package versions, implementation locations, test or module counts, observed Git values, CI wiring, current inventories, framework mechanisms…) are separate claims: "policy X is frozen; 53 current sites implement it" keeps the frozen policy as `KEPT` and disposes the count as `REDISCOVER_ON_DEMAND` — such evidence supports discovery and install reporting but never survives into a Layer-3 rule merely because it was attached to a durable decision, and a candidate whose every claim is current technical evidence yields no Layer-3 candidate at all. Do **not** over-sanitize durable policy: a durable decision legitimately names a technology, an external contract, a compatibility boundary, a migration target or a deliberately frozen behavior when that identity is necessary to express the decision itself — never reduce useful project policy to vague wording merely to strip technical terminology.
- **A developer decision promotes only the decision itself** — confirming a proposed choice (e.g. "use commit convention X") makes that exact approved decision durable policy; the discovery evidence supporting the choice (recently observed history values, current examples) stays rediscoverable unless the developer explicitly approves those exact values as policy.
- **One subject owner per kept clause** — a relocated clause is **moved, never copied**: it must disappear from its original candidate. An available existing owner file is **not** a subject match — a distinct durable subject (a frozen migration decision, a new policy domain…) never lands under an existing `project-*` file merely because that file exists; it gets its established canonical owner when one exists (Git → `project-git-workflow.md`, working language → `project-working-language.md`…), otherwise its own proposed `project-*` name, confirmed by the developer where the choice is genuinely open.
- **Empty candidates are deleted** — after moves and removals, a candidate with zero surviving durable clauses is **neither displayed nor created**: no placeholder, no "no content" entry, no candidate scheduled to disappear after approval.
- **Final consistency assertions before display** — every clause has exactly one disposition and, if kept, exactly one owner; no mixed-subject clause remains; no empty candidate remains; every relocated clause left its source; no Layer-1/Layer-2 duplicate, rediscoverable state or gap-as-policy survives; every factual claim rests on the correct evidence dimension. If any assertion fails, fix the candidate set and re-validate **before** rendering: the first proposal shown to the developer is the normalized, approval-ready one — a second manual sanitization pass must never be needed.

**Approval freezes the Layer-3 set.** The developer's approval turns the normalized result into the **approved normalized Layer-3 set** — for each approved file: the confirmed filename (a developer-confirmed name is authoritative for the run — never reverted, renamed or merged elsewhere), its subject owner, its exact surviving durable clauses and each clause's final disposition, plus the developer choices that shaped it. That set is **immutable for the rest of the install run**: after approval no clause may change disposition (never `FOLLOW_UP → KEPT`, never `REDISCOVER_ON_DEMAND → KEPT`, never `REMOVED_L1`/`REMOVED_L2 → KEPT`), no discovery fact may enter Layer 3 unless it is already in the set, and no new project-owned semantic clause may be invented — any change requires amending the proposal and re-approving **before** any write. At the exact approval boundary, capture the approved set as immutable **`APPROVED_LAYER3_RECORDS`** — one record per approved file: the confirmed filename, its subject owner, the **exact approved semantic clause text, captured verbatim** (never merely the topic, intent, gist or a reconstructed meaning), each clause's final disposition (only `KEPT` clauses enter the records) and the developer decision that shaped it where applicable. After approval the records never mutate: they are the sole post-approval semantic source and the renderer's only input — the renderer never asks "what did the developer probably mean?".

Display the complete structure to be deployed and **wait for validation**. Label every artifact by its actual owner — ownership comes from membership, never from filename or numbering:

- **Framework-owned (Layer 1)**: the universal SDD commands (`sdd-*`, `retro-spec`), the **4 universal SDD agents** (`spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer`), the process templates, and the four canonical rules `00-sdd-framework.md`, `01-git-conventions.md`, `02-security.md`, `03-code-quality.md` — never present them as skill-owned or count them among the Layer-2 artifacts.
- **Selected-skill-owned (Layer 2)**: the stack rules this skill ships in `reference/rules/` beyond the four canonical Layer-1 files, the stack scaffolding commands, and the **stack-adapted `test-generator` agent** (a stack-dependent artifact cannot belong to the universal layer — this skill's reference is its source of truth).
- **Project-owned (Layer 3)**: only the `project-*` rules Phase 4 actually justifies — none is required by default.

**Choice validity gate — ownership validation precedes user choice presentation.** Before presenting any developer choice (clarification question, policy option, filename confirmation), validate every option against Layer ownership: an option whose selection would override or negate a universal Layer-1 invariant, override or negate an applicable selected-skill Layer-2 contract, or redefine the selected-skill target baseline for new work is architecturally invalid — it is an `INVALID_OPTION`, never a `USER_DECISION_REQUIRED`, and it is **never displayed**. Preserving an existing legacy implementation untouched until a dedicated migration is a valid brownfield choice; "Layer 3 overrides the Layer-2 target for new work" never is — brownfield preservation does not redefine the target baseline. When only architecturally invalid alternatives exist, do not manufacture a choice: apply the ownership model deterministically and report a follow-up where appropriate.

The Phase 1 clarification questions are **non-blocking developer choices**: installation proceeds deterministically with the discovered facts if they stay unanswered — offer them, never present them as blockers. Reserve `USER_DECISION_REQUIRED` for a genuinely non-deterministic decision that prevents safe continuation (conflicting durable policies with no deterministic owner, an ambiguous destructive choice); optional matters (constitution ratification, modernization sequencing, the name of an optional new project rule, committing `.claude/` or not…) are offered as questions, never as blockers.

### Phase 3 — Deploy files

Copy from `reference/` to project's `.claude/`, in this order:

```
.claude/agents/spec-writer.md
.claude/agents/plan-architect.md
.claude/agents/task-decomposer.md
.claude/agents/test-generator.md
.claude/agents/code-reviewer.md
.claude/rules/00-sdd-framework.md
.claude/rules/01-git-conventions.md
.claude/rules/02-security.md
.claude/rules/03-code-quality.md
.claude/rules/10-code-conventions.md
.claude/rules/11-tests-strategy.md
.claude/rules/12-quality-gates.md
.claude/rules/60-refactoring-guard.md        (brownfield only)
.claude/rules/61-legacy-rules.md             (brownfield only)
.claude/sdd/_template/spec.md
.claude/sdd/_template/plan.md
.claude/sdd/_template/tasks.md
.claude/sdd/_template/notes.md
.claude/sdd/_template/jira-story-fr.md
.claude/sdd/_template/jira-story-en.md
.claude/sdd/_template/spec-doc-fr.md
.claude/sdd/_template/spec-doc-en.md
.claude/sdd/README.md
.claude/sdd/_archive/.gitkeep
.claude/commands/sdd-start.md
.claude/commands/sdd-spec.md
.claude/commands/sdd-clarify.md
.claude/commands/sdd-spec-check.md
.claude/commands/sdd-plan.md
.claude/commands/sdd-tasks.md
.claude/commands/sdd-implement.md
.claude/commands/sdd-verify.md
.claude/commands/sdd-review.md
.claude/commands/sdd-mr.md
.claude/commands/sdd-archive.md
.claude/commands/sdd-status.md
.claude/commands/sdd-hotfix.md
.claude/commands/sdd-upgrade.md
.claude/commands/sdd-changelog.md
.claude/commands/sdd-revert.md
.claude/commands/retro-spec.md
.claude/commands/php-class.md
.claude/commands/php-test.md
.claude/commands/extract-class.md         (brownfield only)
```

> **CI/CD**: every project keeps its own pipeline. The rules in `.claude/rules/12-quality-gates.md` state what must be green at the quality stage — wire those checks into your existing CI.

### Phase 4 — Materialize the approved Layer-3 set (Layer 2 stays untouched)

**Phase 4 is materialization — never reclassification, discovery or enrichment.** The approved normalized Layer-3 set (Phase 2) is the only **source of truth for what gets written**: create exactly the approved `project-*` filenames, render exactly the approved durable clauses into them, and add only structural formatting (headings, bullets, a generic preamble) that carries **no new project semantics**. Never re-read or reinterpret discovery to "dispose", "complete", "document" or enrich a project rule after approval; never promote a follow-up, gap or observed violation into a "known/approved exception" (an observed violation is an approved exception **only** if the developer approved that exact decision in the proposal); never add rediscoverable technical context; never write a file the approved set does not contain; never omit one it contains.

**Renderer non-authorship — rendering is transcription plus formatting, never semantic authorship.** The renderer's only input is `APPROVED_LAYER3_RECORDS`; its only additions beyond that content are Markdown structure: headings, bullets, ordering, whitespace, a generic non-semantic file header. Rationale, exceptions, responsibility or accountability statements, liability attribution, scope carve-outs, clarifications, normative examples, interpretations, additional constraints, broader or narrower policy, new permissions or prohibitions and inferred intent are **semantic content, never structural formatting** — none of them enters a written file unless it already exists in the approved records. A generic heading such as `## Security` is structural; a heading plus new normative prose is semantic. If during rendering a rule seems too broad, too narrow, ambiguous or incomplete, render-time semantic repair is **forbidden**: stop materializing that rule, report the proposal defect, amend the proposal, ask the developer to re-approve, and capture new immutable approved records before writing.

**Post-write fidelity check — required before announcing success.** The verification baseline is the pre-write `APPROVED_LAYER3_RECORDS`, which existed before rendering started. Re-read every written `project-*` file, extract its semantic claims and compare them against those same pre-write records — never against discovery, a remembered or reconstructed proposal meaning, or inferred developer intent: a renderer that reconstructs the expected meaning after writing is validating itself, not the files. The exact approved filenames exist and no unapproved one does; every approved durable clause is represented; no unapproved semantic clause, follow-up, rediscoverable state, Layer-1/Layer-2 duplicate or relocated clause reappeared; no empty file was materialized. Any mismatch means the installation is **not** successful: fix the materialized files to match the approved records — never re-open discovery to justify the discrepancy.


The Layer-2 files just deployed are **skill-owned**: immediately after installation the project's Layer 2 is **byte-identical to `reference/`**, and it stays that way — never edit a deployed Layer-2 rule with project findings. The classes below govern how every Phase 1 finding is disposed when the Phase-2 gate builds the approved set — **before approval**; after approval they are never re-run to add content:

**Semantic disposition — classify every finding before proposing any Layer-3 persistence:**

- **Framework-owned invariant (Layer 1)** — e.g. the universal Git-trailer prohibitions (`01-git-conventions.md`) or the security baseline (`02-security.md`) → **never restated in a project rule**: Layer 3 specializes project truth, it never repeats Layer 1 or Layer 2 for emphasis.
- **Skill-owned stack contract (Layer 2)** → never duplicated, negated or restated as project target policy.
- **Rediscoverable technical current state** (versions, roots, tool/task/command names, generated-artifact paths, provider/export mechanisms, snapshot presence, current architecture/runner/formatter/CI state, lockfile presence…) → discover on demand; never persisted merely because installation discovered it (skill-specific list below).
- **Project debt / gap / current observation** (a `*_GAP`, a non-blocking CI job, a legacy runner, missing tooling…) → reported in the chat as a follow-up — never converted into Layer-3 target policy and never silently repaired during installation. Report what was **observed**; an inference is a **risk**, not a fact — asserting an actual defect (e.g. real contract drift) requires performed-comparison evidence.
- **Durable human-owned project policy** (a stable team decision SDD must know in future sessions: Git extension points, data-classification/AI-use policy, durable architecture boundaries, approved legacy exceptions, deliberately frozen migration decisions, working language…) → eligible for Layer 3. Such a policy already written in `CLAUDE.md` or other project documentation is **still human policy** — being readable from a file does not make it rediscoverable technical state. Approved legacy exceptions and deliberately frozen migration decisions preserve existing project scope until a dedicated migration — they never negate or redefine Layer-1 or Layer-2 target policy for new work.

**Canonical Layer-3 owners on a fresh install** (when no existing equivalent project rule owns the subject): Git extension points → `project-git-workflow.md`; project security/data-classification policy → `project-security.md`; architecture / testing / quality → `project-architecture.md` / `project-testing.md` / `project-quality.md`; working language → `project-working-language.md`. An existing equivalent project rule keeps its identity — never rename it, never create a second owner. For a genuinely new subject with no canonical owner, propose a clear `project-*` name and let the developer confirm it — never present an invented name as framework-canonical.

**Working language (`project-working-language.md`)** — an established Layer-3 subject owner, exactly like Git and security. It declares the language of project-facing SDD communication (`spec.md`, `plan.md`, `tasks.md`, `notes.md`, project-facing SDD analysis — see `00-sdd-framework.md` § Working language). It never governs Git commit subjects or source-code comments — both stay English under the universal invariants (`01-git-conventions.md`, `03-code-quality.md`), and a working-language decision is never evidence about source-comment language. A fresh install creates only this canonical filename — the known legacy non-canonical alias filename is upgrade-compatibility data owned by `/sdd-upgrade`, never a fresh-install proposal.

**Effective Git policy discovery.** The repository's real Git history and the project's explicit documentation (contributing guide, `CLAUDE.md`, team docs) are the evidence for the CURRENT durable Git convention — exact commit-message format, ticket presence and placement, type/scope usage, branch naming pattern, target branch, no-ticket maintenance format. A Git convention is proposed as durable Layer 3 only when supported by explicit human/project documentation or a sufficiently coherent current/recent Git practice; prefer the current coherent convention — old heterogeneous history is never mechanically counted as equally authoritative. Never promote a universal framework example (e.g. `feature/<TICKET-ID>-<description>`) into Layer 3 as if it were the project's discovered policy, and never infer a ticket convention from tooling state — an unavailable Jira/Confluence MCP proves nothing about ticket usage. When recent evidence is materially inconsistent or insufficient, the exact format is a genuinely open human policy: ask a targeted developer question if the project wants one persisted, otherwise the universal defaults of `01-git-conventions.md` apply as the documented fallback — an unanswered question never blocks installation and never invents a policy. A developer confirmation makes a genuinely open human policy durable; it never turns an unsupported technical inference into an established historical fact.

Skill-specific disposition of the common findings:

- **Discoverable on demand — do not persist**: PHP version and autoloader type (`composer.json`), PHPUnit presence/version (`composer.json`/`composer.lock`), quality tooling configuration (`phpstan.neon`, `.php-cs-fixer.php` where present). Commands read these canonical sources when they need them.
- **Durable project context → Layer 3**: durable naming conventions and architecture decisions that no manifest records — `.claude/rules/project-architecture.md`.
- **Project policies → Layer 3**: the team's quality stance (e.g. lenient gates while the legacy is modernized, then strict) — `.claude/rules/project-quality.md`; a decision to introduce PHPUnit where absent — `.claude/rules/project-testing.md`.
- **Diagnostic only**: the Phase 1 stack report (detected versions, gaps and debt) is announced in the chat and not persisted.

Create a Layer-3 file **only if at least one durable fact or policy needs that subject**; when an existing project rule already owns the subject, reuse it — never create empty or placeholder project files, and never create a second owner for the same subject.

### Phase 5 — Announce completion

```
✅ SDD Framework installed.

Layers deployed:
- Layer 1 (SDD methodology)    : ✅
- Layer 2 (pure PHP stack)     : ✅
- Layer 3 (project skills)     : to be completed in .claude/skills/

SDD agents deployed:
  spec-writer · plan-architect · task-decomposer
  test-generator · code-reviewer

Next steps:
- Create your domain skills in .claude/skills/ if needed
- Start a feature: /sdd-start <FEATURE-ID>-<description>
```

## Critical rules

- **Never modify the source code of the project during this skill execution**. Only `.claude/` is touched.
- **Always wait for validation** before deploying.
- **Brownfield-only files** (`60-refactoring-guard.md`, `61-legacy-rules.md`, `extract-class.md`) are skipped in greenfield mode.
- **Use the `reference/` files as source of truth**. Do not rewrite them from memory.
- **Never edit a deployed Layer-2 rule with project facts** — Layer 2 stays byte-identical to `reference/` (that is what lets `/sdd-upgrade` keep it in sync with the skill); project truth goes to Layer 3 (Phase 4).

## What this skill does NOT do

- Does not create project skills (those are project-specific, the user adds them in `.claude/skills/`)
- Does not configure CI/CD pipelines
- Does not install Composer dependencies
- Does not write production code
