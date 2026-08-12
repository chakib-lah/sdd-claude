# Template: Jira story export (retrospective spec)

<!--
Used by /retro-spec step 8 to derive exports/jira-story.txt from a retrospective spec.md.
The output is Jira WIKI MARKUP, ready to paste into a ticket description.
Before using this structure, check the project's real ticket template (a recent ticket,
read-only, or a local rule): some projects use another issue type with free-form headings.
Write the content in the project's working language. Business content only: no technical
debt, no ✅/⚠️ markers — open questions and 🗣️ declarations go to "Points à confirmer".
Projects may adapt this template to their own ticketing conventions.
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
<management rule — from the business rules found in the ACs and the Design
(computations, entitlements, list-building rules)>

+*RG02 :*+
<next rule — one +*RGnn :*+ block per rule, numbered continuously>

+*Points à confirmer :*+
<open questions and 🗣️ declarations from the spec, one line each>

h3. (/) Critères d'acceptation
||N°||Critères||
|*1*|*Etant donné que* <condition>
*Quand* <action>
*Alors* <résultat>
*Et* <résultat>|
|*2*|<next criterion — ACs converted to Gherkin in the project's working language,
grouped and renumbered; a large module may yield one table per functional group,
each introduced by a h4. heading>|
```
