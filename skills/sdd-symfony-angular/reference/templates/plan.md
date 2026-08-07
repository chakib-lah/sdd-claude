---
feature: <FEATURE-ID>-<description-kebab-case>
status: draft
created: YYYY-MM-DD
author: <author>
---

# Implementation plan: <Readable feature title>

> Spec reference: `./spec.md` (status: approved required)

## Overall approach

<!--
Concise paragraph (5-10 lines) describing the implementation strategy.
- Which main technical approach?
- Why this one rather than another?
- What are the integration constraints with the existing code?
-->

## Implementation order

<!--
Numbered list of the main logical steps.
The order must:
- Minimize the risk of rework
- Allow intermediate validation points
- Follow natural dependencies (model → service → API → UI)
-->

1.
2.
3.
4.

## Impacted files

<!--
Table or list of touched files, with action:
- [CREATE]: new file
- [MODIFY]: modification of an existing file
- [DELETE]: deletion
-->

| File | Action | Reason |
|---|---|---|
| | | |
| | | |

## Risks and mitigations

<!--
Identify the things that can go wrong and the planned mitigation.
-->

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| | Low/Medium/High | Low/Medium/High | |
| | | | |

## Test strategy

<!--
For each acceptance criterion of the spec, indicate:
- Which test type will cover it (unit / integration / functional / E2E)
- On which file or component
- Which edge cases to cover

Reference .claude/rules/11-tests-strategy.md if present.
-->

| AC | Test type | Test file | Covered cases |
|---|---|---|---|
| AC-1 | | | nominal, error, edge |
| AC-2 | | | |
| AC-3 | | | |

## Points of attention

<!--
List of things to watch during implementation:
- Non-regressions to check explicitly
- Potential side effects on other parts of the system
- External dependencies (APIs, third-party services, DB)
- Possible DB migrations and their reversibility
-->

-
-

## Remaining questions

<!--
The open questions from the spec that must be settled before the Tasks phase.
If a question is still here at this stage, it will no longer be possible to settle it later.
-->

-
-
