# Template: Jira story export (retrospective spec) — FR

<!--
Used by /retro-spec step 8 to derive exports/jira-story.txt from a retrospective spec.md.
The export is the content of the fenced block below (Jira WIKI MARKUP, ready to paste):
strip this title, this comment and the fence. FR variant — an EN variant
(jira-story-en.md) exists: /retro-spec picks the one matching the project's working
language, and translates from the -en variant for any other language. Filling rules
(business-only content, points to confirm, ticket-template check) live in /retro-spec
step 8. Projects may adapt this file to their own ticketing conventions.
-->

```
h3. (on) Résumé
{panel}
*En tant que* : <persona derived from the spec's Objectives>
*Je souhaite* : <capability, from the Objectives>
*Afin de* : <business outcome>
{panel}

+*Contexte :*+
<condensed "Context and problem" from the spec>

+*RG01 :*+
<management rule — from the business rules found in the ACs and the Functional behavior section
(computations, entitlements, list-building rules)>

+*RG02 :*+
<next rule — one +*RGnn :*+ block per rule, numbered continuously>

+*Points à confirmer :*+
<open questions and 🗣️ declarations from the spec, one line each>

h3. (/) Critères d'acceptation
||N°||Critères||
|*1*|*Étant donné que* <condition>
*Quand* <action>
*Alors* <résultat>
*Et* <résultat>|
|*2*|<next criterion — ACs converted to Gherkin in the project's working language,
grouped and renumbered; a large module may yield one table per functional group,
each introduced by a h4. heading>|
```
