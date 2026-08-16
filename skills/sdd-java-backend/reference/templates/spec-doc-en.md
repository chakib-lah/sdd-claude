# FUNCTIONAL SPECIFICATION — <Module name>

<!--
Used by /retro-spec step 8 to derive exports/spec-doc.md from a retrospective spec.md.
The export follows this skeleton: strip the HTML comments, replace the <placeholders>.
EN variant — a FR variant (spec-doc-fr.md) exists: /retro-spec picks the one matching
the project's working language, and translates from this -en variant for any other
language. Filling rules (business-only content, "Source:" file paths without line
numbers, revision from analyzed_branch/analyzed_commit — never the current HEAD, which is
only a flagged fallback when those fields are missing) live in /retro-spec step 8. If the user provides their own document format, /retro-spec bases the
export on it and OFFERS (asks first) to save it as the project's override of this file.
-->

| | |
|---|---|
| **Application** | <application name> |
| **Screen / URL** | <screens and URLs, from the spec's `target` and Design endpoints> |
| **Route** | <route name(s)> |
| **Reference branch** | <analyzed_branch> |
| **Reference commit** | <analyzed_commit> |
| **Generation date** | <date> |

> Generated from the source code — to be validated functionally. This document describes
> the behavior observed in the code at the revision above. It does not replace business
> validation.

---

## 1. General overview

### 1.1 Module purpose

<!-- What the module does for its users, in business terms. End with: Source: <files> -->

### 1.2 Users and entitlements

<!-- Entitlement matrix: | Authorization | Allowed roles | Scope | — plus any observed
     anomaly (declared-but-unused authorization, etc.). Source: <files> -->

| Authorization | Allowed roles | Scope |
|---|---|---|

### 1.3 Position in the application journey

<!-- Where the module sits: menus, breadcrumb, screens it links to. Source: <files> -->

## 2. Functional specifications

### 2.1 Screen structure

### 2.2 Available filters

<!-- One row per filter: | Field | Screen label | Type | Behavior | -->

### 2.3 Grid columns

### 2.4 Interface behaviors

### 2.5 Interactions with other modules

<!-- What this module displays from others, and what it provides to others. -->

## 3. Business rules

<!-- One **BRnn — <title>.** block per business rule, each followed by:
     Source: <file> -->

### Access-control rules

## 4. Usage / Operating procedure

### 4.1 Prerequisites

### 4.2 Nominal path

### 4.3 Error cases and messages

<!-- | Situation | Observed behavior | — exact messages as coded. -->

| Situation | Observed behavior |
|---|---|

## 5. Areas of uncertainty / points to confirm

<!-- The spec's open questions and 🗣️ declarations, each with its investigation lead. -->

## Technical annex — analyzed source files

<!-- From the spec's implemented_in plus the context files listed in its Design. -->
