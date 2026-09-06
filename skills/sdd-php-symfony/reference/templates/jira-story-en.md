# Template: Jira story export (retrospective spec) — EN

<!--
Used by /retro-spec step 8 to derive exports/jira-story.txt from a retrospective spec.md.
The export is the content of the fenced block below (Jira WIKI MARKUP, ready to paste):
strip this title, this comment and the fence. EN variant — a FR variant
(jira-story-fr.md) exists: /retro-spec picks the one matching the project's working
language, and translates from this -en variant for any other language. Filling rules
(business-only content, points to confirm, ticket-template check) live in /retro-spec
step 8. Projects may adapt this file to their own ticketing conventions.
-->

```
h3. (on) Summary
{panel}
*As a* : <persona derived from the spec's Objectives>
*I want* : <capability, from the Objectives>
*So that* : <business outcome>
{panel}

+*Context:*+
<condensed "Context and problem" from the spec>

+*BR01:*+
<business rule — from the rules found in the ACs and the Functional behavior section
(computations, entitlements, list-building rules)>

+*BR02:*+
<next rule — one +*BRnn:*+ block per rule, numbered continuously>

+*Points to confirm:*+
<open questions and 🗣️ declarations from the spec, one line each>

h3. (/) Acceptance criteria
||No.||Criteria||
|*1*|*Given* <condition>
*When* <action>
*Then* <result>
*And* <result>|
|*2*|<next criterion — ACs converted to Gherkin in the project's working language,
grouped and renumbered; a large module may yield one table per functional group,
each introduced by a h4. heading>|
```
