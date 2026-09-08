---
description: SDD quality gate — checks the quality of a spec before approval
---

# /sdd-spec-check

**Quality gate**: mechanically validate that a spec meets all the quality criteria before setting it to `status: approved`.

This command can be run at any time while writing the spec, and is particularly useful right before manual approval.

## Prerequisites

- An active SDD feature must exist
- `spec.md` must exist (status `draft` or `in-review`)

## Steps

### 1. Detect the active feature

From the current Git branch.

### 2. Read `spec.md`

### 2b. Validate the AC schema (eligibility — before any scoring)

Enumerate **every** checkbox line of the "Acceptance criteria" section. Each criterion must carry **exactly one** canonical `AC-N` identifier (`AC-` followed by digits whose integer value is **≥ 1** — numbering starts at `AC-1`, so `AC-0` is not canonical; the identifier sits on the checkbox line, and a `[SEC]` tag, when present, sits after it), and every canonical identifier must be **unique**. Numeric gaps are allowed (stable identifiers — a missing number means a removed AC).

This is an **eligibility gate, not a scored criterion**: if any criterion lacks a canonical `AC-N` (bare checkbox, legacy label such as `CA-N`, or a mixed section) or an `AC-N` is duplicated, **stop before scoring**:

```
❌ Acceptance-criteria schema not canonical — check stopped before scoring.

Offending line(s): <quote each non-canonical or duplicated criterion line>

Migrate the metadata manually — preserve every criterion's wording, meaning
and order; add stable AC-N identifiers; update unambiguous legacy references;
ask where a mapping is ambiguous; never invent, remove, merge or split ACs.
Commit the metadata migration when appropriate, then re-run /sdd-spec-check.
```

An already-`approved` artifact never re-enters this command by itself — `/sdd-review` applies the same schema defense at its own gate.

### 3. Run the quality checklist

For each criterion, display ✅ (OK) or ❌ (problem) with an actionable comment.

#### Structure criteria

- [ ] **Complete frontmatter**: `feature`, `status`, `created`, `author` present
- [ ] **Context section**: present and not empty
- [ ] **Objectives section**: present and not empty
- [ ] **Out of scope section**: present and not empty (at least one item)
- [ ] **Acceptance criteria section**: present with at least 2 ACs
- [ ] **Functional behavior section**: present and describes the expected behavior in observable terms
- [ ] **Open questions section**: present (empty = no open questions = a good sign)

#### Acceptance criteria criteria

For each AC:
- [ ] **Format**: starts with "When" (or equivalent), contains an observable result
- [ ] **Testable**: describes a binary behavior (passes or does not pass)
- [ ] **Not vague**: no terms like "performant", "fast", "user-friendly" without a measurable threshold
- [ ] **Non-regression**: at least one AC covers adjacent functionality

#### Content criteria

- [ ] **No structural open questions**: no question in "Open questions" that would change the architecture or the scope if resolved differently
- [ ] **WHAT/WHY only — semantic HOW detection, not just headings**: the spec contains no implementation design and no implementation-only requirement, wherever it appears (any section or AC). Reject or flag: exact source paths and impacted-file lists; class/service/method/component names as change targets ("modify Component X"); code snippets and build commands; **implementation cleanup** ("remove the CSS override", "delete the obsolete selector", "no obsolete rule remains"); internal APIs or technical mechanisms named as the implementation means; implementation-specific workarounds; implementation-only technical constraints. Every AC must assert observable behavior — an AC that merely verifies internal code cleanup fails this criterion. For each finding, name the destination: an implementation decision → `plan.md`; discovery/current-state evidence → `notes.md` — never suggest deleting the information. An **approved observable contract detail is legitimate and must NOT be flagged**: a design-system size (`medium`), a visible icon, a breakpoint requirement ("no overflow at 768px"), an unchanged accessible name, an API backward-compatibility promise, a business formula that is itself the required behavior
- [ ] **No undefined jargon**: domain-specific terms are explained at least once
- [ ] **Constitution respected**: if `.claude/rules/project-constitution.md` exists with `status: ratified`, the spec violates none of its principles (cite the `PN` otherwise). If it exists with `status: draft`, note any violation **informatively** and count the criterion as ✅. If there is no project constitution, count this criterion as ✅ and note "no constitution".

#### Security criteria

- [ ] **Security section handled**: the "Security considerations" section is filled, or contains a one-line justification of non-applicability (an empty section with neither = ❌)
- [ ] **`[SEC]` ACs present when required**: if the feature touches authentication, personal data, money, file handling or any external input, at least one AC is tagged `[SEC]`. If none of those apply, count this criterion as ✅ and note "no security surface".

### 4. Compute a score

```
Score: N/M criteria OK
```

### 5. Produce the report

```
═══════════════════════════════════════════════════
  Spec Quality Check — <FEATURE-ID>
═══════════════════════════════════════════════════

Structure
  Complete frontmatter      : ✅
  Context                   : ✅
  Objectives                : ✅
  Out of scope              : ❌ Section present but empty
  Functional behavior       : ✅
  Acceptance criteria       : ✅ 4 ACs
  Open questions            : ✅ section present

Acceptance criteria
  "When X → Y" format       : ✅ 4/4
  Testable / binary         : ✅
  Not vague                 : ❌ AC-3 too vague: "the system must be responsive"
  Non-regression covered    : ✅

Content
  No structural questions   : ❌ "What behavior if the user has no role?" would change the scope
  WHAT/WHY only             : ✅ (no implementation design in the spec)
  No undefined jargon       : ✅
  Constitution respected    : ✅ (or ❌ violates P3 — <principle name>)

Security
  Security section handled  : ✅
  [SEC] ACs when required   : ✅ (no security surface)

═══════════════════════════════════════════════════
  Score: 14/17
  Status: ⚠️ FIXES REQUIRED
═══════════════════════════════════════════════════

Actions to take before approving:
1. "Out of scope" section: add at least one explicit item
2. AC-3: replace "responsive" with a measurable threshold (e.g. "responds in under 200ms")
3. Open question: "What behavior if the user has no role?" — resolve before approval
```

### 6. Announce the result

- **Score 17/17** → `✅ Spec ready for approval. Set status to "approved" and run /sdd-plan.`
- **Score ≥ 14/17** → `⚠️ Minor fixes required. See the points above (or run /sdd-clarify to resolve them interactively).`
- **Score < 14/17** → `❌ Spec not ready. Significant revisions needed — run /sdd-clarify.`

## Stop rules

- **Read-only**: no file modified
- **Do not modify spec.md** automatically — report the problems; fixing them is the human's job
- **Do not set status to `approved`** automatically — always a human act
