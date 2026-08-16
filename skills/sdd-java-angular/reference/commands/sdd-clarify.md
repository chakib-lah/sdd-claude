---
description: SDD phase 1 — dedicated ambiguity-resolution pass on spec.md before approval
---

# /sdd-clarify

**SDD Phase 1 (complement)**: hunt down ambiguities in an existing `spec.md` and resolve them with the user **before** the spec is approved.

`/sdd-spec` writes the spec in a single interview pass. `/sdd-clarify` is the dedicated second pass: it re-reads the spec cold, detects everything that is still vague, contradictory or unresolved, and asks only about that. Run it (possibly several times) between `/sdd-spec` and the manual approval, typically after a `/sdd-spec-check` that flags problems.

## Blocking prerequisites

- An active SDD feature must exist (folder `.claude/sdd/<feature>/`)
- `spec.md` must exist with `status: draft` or `in-review`

If `spec.md` is already `approved`, **refuse**: an approved spec is frozen. The human must consciously set it back to `draft` before clarifying further.

## Steps

### 1. Detect the active feature

Identify the feature from the Git branch. If ambiguous, apply the fallback in `.claude/rules/00-sdd-framework.md` (§ Active-feature detection).

### 2. Read `spec.md` in full

### 3. Detect the ambiguities

Scan the spec for, in priority order:

1. **Unresolved structural open questions** — anything in "Open questions" that would change the architecture or the scope
2. **Security ambiguities** — unstated data sensitivity, unstated authorization/ownership rules (who can access what), unvalidated external input, missing abuse cases
3. **Vague terms without a measurable threshold** — "fast", "performant", "user-friendly", "robust", "soon", "many"…
4. **ACs missing their error/edge cases** — an AC that only describes the nominal path
5. **Contradictions** — between Objectives, ACs, Out of scope and Design
6. **Undefined jargon** — domain terms never explained
7. **Silent assumptions** — behaviors the Design implies but no AC pins down (permissions, empty states, concurrency, i18n, pagination…)

### 4. Ask at most 5 targeted questions

Use `AskUserQuestion` (or equivalent) with **at most 5 questions per run**, most-structural first. For each question, propose concrete answer options whenever possible (this speeds up the decision and avoids re-ambiguity).

Do not ask a question whose answer is already in the spec, the ticket or the code.

### 5. Update `spec.md` with the answers

Apply each answer where it belongs:
- Sharpen the affected AC (or add the missing error-case AC). A new AC takes the **next free number** — AC identifiers are stable for life: never renumber existing ACs; a removed AC leaves a hole
- Move newly excluded items to "Out of scope"
- Record security answers (data sensitivity, authorization rules, input validation, abuse cases) under "Security considerations" — any resulting AC is tagged `[SEC]`
- Record decisions and their rationale under "Technical constraints"
- Remove the resolved entries from "Open questions"

Keep `status` unchanged (`draft` or `in-review`).

### 6. Announce in the chat

```
✅ Clarification pass done: .claude/sdd/<feature>/spec.md

Resolved: N ambiguities (list)
Still open: N questions (list — re-run /sdd-clarify or resolve manually)

Next step:
1. Run /sdd-spec-check to score the spec
2. When ready, set status to "approved" and run /sdd-plan
```

## Stop rules

- **Maximum 5 questions per run** — re-run the command rather than interrogate in bulk
- **Read-only on the project's source code** — only `spec.md` is modified
- **Never set the status to `approved`** — that is a human act
- **Refuse on an approved spec** — de-approving is a conscious human decision
- If an ambiguity cannot be resolved by the user, leave it explicitly in "Open questions" rather than inventing an answer
