---
feature: <FEATURE-ID>-<description-kebab-case>
status: draft
created: YYYY-MM-DD
author: <author>
---

# Spec: <Readable feature title>

## Context and problem

<!--
2-4 paragraphs answering:
- What is the business or technical problem?
- Why are we solving it now?
- What is the context (Production, debt, customer request...)?
-->

## Objectives

<!--
Bullet list of expected outcomes, phrased as accomplishments.
No more than 5 objectives: if there are more, it should probably be split into several features.
-->

-
-

## Out of scope

<!--
Explicit list of what is NOT done in this feature.
Include things that might seem obvious but are deliberately excluded.
This section is crucial to avoid scope creep.
-->

-
-

## Functional behavior

<!--
The expected business/functional behavior — the WHAT, never the HOW:
- Business rules applied (a business formula that IS the required behavior belongs here)
- User-visible flows, error handling as the user observes it
- Externally observable contracts that are part of the request
  (e.g. "the existing API response stays backward compatible")

Never put implementation design here: no source paths, no impacted files,
no class/service/method names, no code snippets, no build commands, no DB
implementation details — those belong to plan.md (Technical design).
-->

## Acceptance criteria

<!--
Mandatory format (AC-N is a stable identifier, numbered sequentially from AC-1):
- [ ] AC-N: When [situation], the system [action] and [expected result]

Each AC must be:
- Testable (a test can be written to validate it)
- Measurable (binary: passes or does not pass)
- Precise (no "must be performant" without a threshold)

Include non-regression ACs if the feature touches existing code.

Numbering rule: identifiers are stable for life — never renumber an existing
AC; a removed AC leaves a hole; a new AC (e.g. added by /sdd-clarify) takes
the next free number. The [SEC] tag sits after the identifier:
- [ ] AC-4 [SEC]: When ...
-->

- [ ] AC-1: When
- [ ] AC-2: When
- [ ] AC-3: When

## Security considerations

<!--
Mandatory when the feature touches authentication, personal data, money,
file handling, or any external input. See `rules/02-security.md`.
- Data sensitivity: what data is touched (public / internal / personal / secret)?
- Authentication / authorization impact: new endpoints, new roles, object-level checks (IDOR)?
- External inputs: what is validated, where, against which allow-list?
- Abuse cases: hostile input, enumeration, replay, resource exhaustion?
- Security acceptance criteria: add them to the AC section above, tagged [SEC] after the identifier (`- [ ] AC-4 [SEC]: When ...`).
If truly not applicable, state why in one line instead of deleting the section.
-->

-

## Technical constraints

<!--
Externally observable constraints that are part of the requested contract:
- Standards to comply with (PCI, GDPR, accessibility, etc.)
- Performance constraints (response time, data volume...)
- Security constraints (encryption, RBAC...)
- Compatibility constraints (browser versions, mobile, etc.)
Implementation decisions and their justification belong to plan.md.
-->

## Open questions

<!--
List of points that have not been settled yet.

Rule: STRUCTURALLY SIGNIFICANT questions (which would change the architecture or the scope) must be resolved BEFORE moving to `status: approved`.
DETAIL questions can be deferred to the Plan phase.
-->

-
-
