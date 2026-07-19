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

### 3. Run the quality checklist

For each criterion, display ✅ (OK) or ❌ (problem) with an actionable comment.

#### Structure criteria

- [ ] **Complete frontmatter**: `feature`, `status`, `created`, `author` present
- [ ] **Context section**: present and not empty
- [ ] **Objectives section**: present and not empty
- [ ] **Out of scope section**: present and not empty (at least one item)
- [ ] **Acceptance criteria section**: present with at least 2 ACs
- [ ] **Design section**: present and references existing files/services/entities
- [ ] **Open questions section**: present (empty = no open questions = a good sign)

#### Acceptance criteria criteria

For each AC:
- [ ] **Format**: starts with "When" (or equivalent), contains an observable result
- [ ] **Testable**: describes a binary behavior (passes or does not pass)
- [ ] **Not vague**: no terms like "performant", "fast", "user-friendly" without a measurable threshold
- [ ] **Non-regression**: at least one AC covers adjacent functionality

#### Design criteria

- [ ] **No structural open questions**: no question in "Open questions" that would change the architecture or the scope if resolved differently
- [ ] **Impacted files mentioned**: the Design section points to specific files/services/entities (not "the users service")
- [ ] **No undefined jargon**: domain-specific terms are explained at least once
- [ ] **Constitution respected**: if `.claude/rules/05-constitution.md` exists with `status: ratified`, the spec violates none of its principles (cite the `PN` otherwise). If there is no ratified constitution, count this criterion as ✅ and note "no constitution".

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
  Acceptance criteria       : ✅ 4 ACs
  Design                    : ✅
  Open questions            : ⚠️ 1 structural question open

Acceptance criteria
  "When X → Y" format       : ✅ 4/4
  Testable / binary         : ❌ AC-3 too vague: "the system must be responsive"
  Non-regression covered    : ✅

Design
  Specific files mentioned  : ✅
  No undefined jargon       : ✅
  Constitution respected    : ✅ (or ❌ violates P3 — <principle name>)

═══════════════════════════════════════════════════
  Score: 11/14
  Status: ⚠️ FIXES REQUIRED
═══════════════════════════════════════════════════

Actions to take before approving:
1. "Out of scope" section: add at least one explicit item
2. AC-3: replace "responsive" with a measurable threshold (e.g. "responds in under 200ms")
3. Open question: "What behavior if the user has no role?" — resolve before approval
```

### 6. Announce the result

- **Score 14/14** → `✅ Spec ready for approval. Set status to "approved" and run /sdd-plan.`
- **Score ≥ 11/14** → `⚠️ Minor fixes required. See the points above (or run /sdd-clarify to resolve them interactively).`
- **Score < 11/14** → `❌ Spec not ready. Significant revisions needed — run /sdd-clarify.`

## Stop rules

- **Read-only**: no file modified
- **Do not modify spec.md** automatically — report the problems; fixing them is the human's job
- **Do not set status to `approved`** automatically — always a human act
