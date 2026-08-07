# Project Constitution

> **Layer 1 skeleton — to be filled in and ratified by the team.**
> This file holds the project's **durable engineering principles**: the decisions that outlive any single feature. Specs, plans and reviews are checked against it — `/sdd-spec-check` and `/sdd-review` treat a violation of a ratified principle as a blocking finding.
> Until it is ratified (see frontmatter below), the checks that reference it are skipped.

---
project: <project-name>
status: draft            # draft | ratified — only the team sets "ratified"
ratified: <YYYY-MM-DD or empty>
amended: <YYYY-MM-DD or empty>
---

## How this file works

- Principles are **numbered and stable**: `P1`, `P2`, … A principle is never renumbered; a withdrawn principle keeps its number with the mention *(withdrawn on <date>)*.
- Each principle states the **rule**, its **rationale**, and what counts as a **violation**. A principle nobody can violate is not a principle — remove it.
- Keep it short: **5 to 12 principles**. Beyond that, it becomes a style guide (that belongs in `10-code-conventions.md`).
- **Amendment procedure**: team discussion → MR editing this file → update `amended` date. Never amended by an agent.

## Principles

### P1 — <Name of the principle>

- **Rule**: <the durable decision, phrased so a reviewer can apply it — e.g. "Every API change is backward-compatible for one release cycle">
- **Rationale**: <why the team chose this — the cost it avoids>
- **Violation looks like**: <a concrete example a review would flag>

### P2 — <Name of the principle>

- **Rule**: <…>
- **Rationale**: <…>
- **Violation looks like**: <…>

<!-- Add P3…PN following the same structure. Suggested themes to consider
     (keep only what your team actually commits to):
     - Simplicity first / no speculative abstraction
     - Test discipline beyond the quality gates (e.g. test-first for bugfixes)
     - Backward compatibility & migration policy
     - Observability expectations (logs, metrics on every new endpoint)
     - Data ownership & privacy boundaries
     - Dependency policy (when a new library is acceptable)
     - Performance budgets (thresholds a feature may not degrade)
-->

## Scope of authority

| Question | Answered by |
|---|---|
| Durable engineering principles (WHY) | **this file** |
| SDD process (phases, gates, statuses) | `00-sdd-framework.md` |
| Stack conventions (HOW to write code) | `10-code-conventions.md` and other Layer 2 rules |
| Feature-specific decisions | the feature's `spec.md` / `plan.md` |

In case of conflict: a ratified constitution wins over Layer 2 conventions; the SDD framework rules (`00-sdd-framework.md`) govern the process regardless.
