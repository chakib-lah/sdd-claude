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

## Acceptance criteria

<!--
Mandatory format:
- [ ] When [situation], the system [action] and [expected result]

Each AC must be:
- Testable (a test can be written to validate it)
- Measurable (binary: passes or does not pass)
- Precise (no "must be performant" without a threshold)

Include non-regression ACs if the feature touches existing code.
-->

- [ ] When
- [ ] When
- [ ] When

## Design

<!--
Technical sections to adapt depending on the nature of the feature and the project's stack.
The examples below are suggestions to enable/disable depending on context.
-->

### Endpoints / API

<!--
If the feature affects endpoints:
- HTTP method
- Exact route
- Request payload (with types)
- Response (with types and HTTP codes)
- Required authentication
-->

### Data model / DB

<!--
If the feature affects persistence:
- Entities created or modified
- Fields added / removed / modified
- Required indexes
- DB migration reversible or not
-->

### UI / Frontend components

<!--
If the feature affects the frontend:
- Components created or modified
- Inputs / outputs
- Managed states
- Key user interactions
-->

### Services and business logic

<!--
- New services to create
- Existing services to modify (and impact on their other consumers)
- Applied business rules
-->

### External integrations

<!--
- Third-party APIs called
- Authentication (keys, tokens, OAuth...)
- Error / timeout / retry handling
-->

## Security considerations

<!--
Mandatory when the feature touches authentication, personal data, money,
file handling, or any external input. See `rules/03-security.md`.
- Data sensitivity: what data is touched (public / internal / personal / secret)?
- Authentication / authorization impact: new endpoints, new roles, object-level checks (IDOR)?
- External inputs: what is validated, where, against which allow-list?
- Abuse cases: hostile input, enumeration, replay, resource exhaustion?
- Security acceptance criteria: add them to the AC section above, tagged [SEC].
If truly not applicable, state why in one line instead of deleting the section.
-->

-

## Technical constraints

<!--
- Technical decisions made and their justification
- Standards to comply with (PCI, GDPR, accessibility, etc.)
- Performance constraints (response time, data volume...)
- Security constraints (encryption, RBAC...)
- Compatibility constraints (browser versions, mobile, etc.)
-->

## Open questions

<!--
List of points that have not been settled yet.

Rule: STRUCTURALLY SIGNIFICANT questions (which would change the architecture or the scope) must be resolved BEFORE moving to `status: approved`.
DETAIL questions can be deferred to the Plan phase.
-->

-
-
