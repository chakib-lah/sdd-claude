# SPÉCIFICATION FONCTIONNELLE — <Module name>

<!--
Used by /retro-spec step 8 to derive exports/spec-doc.md from a retrospective spec.md.
Write the document in the project's working language. Business content only: no technical
debt section — uncertainties go to chapter 5. Every "Source :" reference is a file path
WITHOUT line numbers (the export is derived from spec.md without re-reading the code).
The header revision comes from the spec frontmatter (analyzed_branch / analyzed_commit),
NOT from the current HEAD. If the user provides their own document format, base the export
on it instead and save it as the project's override of this template.
-->

| | |
|---|---|
| **Application** | <application name> |
| **Écran / URL** | <screens and URLs, from the spec's `target` and Design endpoints> |
| **Route** | <route name(s)> |
| **Branche de référence** | <analyzed_branch> |
| **Commit de référence** | <analyzed_commit> |
| **Date de génération** | <date> |

> Généré à partir du code source — à valider fonctionnellement. Ce document décrit le
> comportement observé dans le code à la révision indiquée ci-dessus. Il ne se substitue pas
> à une validation métier.

---

## 1. Présentation générale

### 1.1 Objectif du module

<!-- What the module does for its users, in business terms. End with: Source : <files> -->

### 1.2 Utilisateurs concernés

<!-- Entitlement matrix: | Autorisation | Rôles autorisés | Portée | — plus any observed
     anomaly (declared-but-unused authorization, etc.). Source : <files> -->

| Autorisation | Rôles autorisés | Portée |
|---|---|---|

### 1.3 Position dans le parcours applicatif

<!-- Where the module sits: menus, breadcrumb, screens it links to. Source : <files> -->

## 2. Spécifications fonctionnelles

### 2.1 Structure de l'écran

### 2.2 Filtres disponibles

<!-- One row per filter: | Champ | Libellé écran | Type | Comportement | -->

### 2.3 Colonnes de la grille

### 2.4 Comportements d'interface

### 2.5 Interactions avec les autres modules

<!-- What this module displays from others, and what it provides to others. -->

## 3. Règles de gestion

<!-- One **RGnn — <title>.** block per business rule, each followed by:
     Source : <file> -->

### Règles de droits d'accès

## 4. Utilisation / Mode opératoire

### 4.1 Prérequis

### 4.2 Parcours nominal

### 4.3 Cas d'erreur et messages associés

<!-- | Situation | Comportement observé | — exact messages as coded. -->

| Situation | Comportement observé |
|---|---|

## 5. Zones d'incertitude / points à confirmer

<!-- The spec's open questions and 🗣️ declarations, each with its investigation lead. -->

## Annexe technique — fichiers sources analysés

<!-- From the spec's implemented_in plus the context files listed in its Design. -->
