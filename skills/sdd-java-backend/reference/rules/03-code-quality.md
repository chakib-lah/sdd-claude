# Code Quality Rules — Generic Development Baseline

> **Layer 1 — Universal methodology.**
> These rules are stack-agnostic: true for every project, whatever the technology. They state **principles only** — where a practice needs a tool to be expressed (a linter directive, a suppression annotation, a coverage flag), the principle lives here and the tool's name and syntax belong to the Layer 2 `rules/` of each skill (`10-code-conventions.md`, `12-quality-gates.md`).
> Security-flavored quality rules are **owned by `02-security.md`** — this file cross-references them and never restates them.

---

## Golden rule

> **Code is read far more often than it is written.**
> A change that passes the tests but degrades legibility, traceability or reversibility is not done. Every rule below protects the next reader.

---

## Who applies this file

| Consumer | When | Duty |
|---|---|---|
| `/sdd-implement` | while writing code | loads this file alongside the other rules and applies it to every task |
| `code-reviewer` agent | during the review | checks the diff against this file and flags each violation with file:line |
| `/sdd-review` | functional gate | reports the violations in its gate report — a violation of a non-negotiable below is blocking |

---

## Baseline rules (always apply)

### Traces and cleanliness
- No leftover debug output: print, dump or log statements added while debugging are removed before commit. The stack's concrete debug functions are listed in `10-code-conventions.md`.
- No commented-out code — history lives in version control, not in comments.
- `TODO` / `FIXME` only with an associated ticket referenced on the same line. An anonymous `TODO` is a task nobody owns.
- No hardcoded secret — owned by `02-security.md` § Secrets management; apply it as written there.

### Readability
- Explicit naming: a name says what the thing is or does, without needing the surrounding code to decode it.
- A function does one thing. If describing it honestly requires "and", split it.
- No magic number: any literal whose meaning is not obvious in context is a named constant.

### Error handling
- Never swallow an exception: an error is handled, translated, or propagated — never silently discarded.
- Never fail silently: a code path that cannot do its job says so (error, log, explicit return), it does not pretend it succeeded.

### External input
- Every external input is validated at its entry point — the rules are owned by `02-security.md` § Input validation and § Injection prevention; apply them as written there.

### Non-regression
- Any change to an existing behaviour requires a test that attests the new behaviour. No attested behaviour, no change.

### No dead code
- No unreachable function, unused import, unused variable or unreachable branch survives a change. Delete it — version control remembers.

### No duplicated business logic
- A business rule lives in exactly one place. Duplicating it creates two versions of the truth that will diverge.

### Backward compatibility
- A changed public signature requires either updating every caller in the same change, or a documented deprecation path with a removal target.

### Dependencies
- No dependency added without justification in `plan.md`, stating the alternative rejected. The audit duty on dependencies is owned by `02-security.md` § Dependencies.

### No quality bypass
- Suppression or ignore directives — whatever the tool calls them — are forbidden without a written, dated justification. The concrete directive syntax per tool belongs to Layer 2 (`10-code-conventions.md`, `12-quality-gates.md`).

### Test honesty
- A change made for a test must be true in production: no test-only branch, flag or shortcut in shipped code.

### Generated files
- Generated files are never hand-edited — change the source and regenerate. A hand edit is destroyed by the next generation.

### Data migrations
- No logic in a data migration beyond the transformation itself. Business decisions belong to the code that runs before and after, not to a one-shot script.

---

## Non-negotiables

- Never ship a suppression/ignore directive without its written, dated justification.
- Never ship a test-only branch in production code.
- Never hand-edit a generated file.
- Never change an existing behaviour without a test attesting the new one.
