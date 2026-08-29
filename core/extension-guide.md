# Extension guide — Creating a stack skill

> How to add a technology-specific skill (PHP/Symfony, Symfony+Angular, Java/Spring, Python/Django, Go, etc.) that plugs into the toolkit's common methodology core.

---

## Principle

The toolkit stacks **3 layers**. The boundary is not a feeling — it is a decision test, applied sentence by sentence:

- **Layer 1 — Universal methodology**: true for every project, whatever the technology. **If a sentence names anything stack-dependent — an application framework, a programming language, a package or build tool (`composer install`, `npm audit`, `./gradlew check`) — it is not Layer 1. Naming an SDD command (`/sdd-verify`) or stack-agnostic workflow tooling (`git`) is expected: those ARE Layer 1 vocabulary — the boundary is stack-dependent vs stack-agnostic, not tool vs no tool.** Content: the 17 SDD commands, the 5 SDD agents, the templates and the 4 process rules (`00-sdd-framework.md`, `02-git-conventions.md`, `03-security.md`, `04-code-quality.md`). Identical everywhere, never adapted.
- **Layer 2 — Technology**: true for the whole stack, whatever the project. **If a sentence names a branch, a ticket prefix, a host or a project path, it is not Layer 2.** Content: code rules, test strategy, quality gates and scaffolding commands specific to the stack — **every rule file the skill ships in `reference/rules/` that is not one of the four canonical Layer-1 files**; some are numbered (`10-…`), some are not (`api-contracts.md`): the name decides nothing, reference membership does.
- **Layer 3 — Project**: everything else — business skills, house conventions, project-specific code templates (added by the team).

In a deployed project, **ownership is resolved mechanically, never by filename prefix**: a rule is Layer 1 if it is one of the four canonical files (`00-sdd-framework.md`, `02-git-conventions.md`, `03-security.md`, `04-code-quality.md`); else Layer 2 if the selected skill's `reference/rules/` ships the same relative path; else Layer 3 (project-owned — `/sdd-upgrade` never byte-replaces it). Layer 1 carries no project-override block: project truth lives in Layer 3. A rule that fails its layer's test is in the wrong file, whatever its name says.

A **stack skill** packages Layer 1 **(copied verbatim)** + Layer 2 **(stack-specific)**. Layer 3 is added per project, after installation.

---

## Anatomy of a stack skill

A skill lives in `skills/sdd-<stack>/`. It carries a `SKILL.md` (frontmatter + scope description) and a `reference/` directory whose content is deployed into the project's `.claude/` at installation time.

```
skills/sdd-<stack>/
├── SKILL.md                          ← frontmatter (name, description), scope, triggers
└── reference/
    ├── agents/                       ← 5 SDD agents
    │   ├── spec-writer.md            ← MASTER (copied verbatim from core)
    │   ├── plan-architect.md         ← MASTER
    │   ├── task-decomposer.md        ← MASTER
    │   ├── code-reviewer.md          ← MASTER
    │   └── test-generator.md         ← ONLY agent adapted to the stack
    ├── commands/                     ← 17 SDD commands + scaffolding commands
    │   ├── sdd-start.md … retro-spec.md   ← 17 MASTERS (copied verbatim from core)
    │   └── <stack>-entity.md, <stack>-test.md, …   ← stack-specific (Layer 2)
    ├── rules/
    │   ├── 00-sdd-framework.md       ← MASTER (methodology, copied from core)
        │   ├── 02-git-conventions.md     ← MASTER (Git, copied from core)
    │   ├── 03-security.md            ← MASTER (security baseline, copied from core)
    │   ├── 04-code-quality.md        ← MASTER (code-quality baseline, copied from core)
    │   ├── 10-code-conventions.md    ← stack-specific (Layer 2)
    │   ├── 11-tests-strategy.md      ← stack-specific (Layer 2)
    │   ├── 12-quality-gates.md       ← stack-specific (Layer 2)
    │   └── <stack extras>.md         ← e.g. doctrine-conventions, angular-conventions, migration-guard…
    └── templates/                    ← 9 process templates
        └── spec.md, plan.md, tasks.md, notes.md, sdd-readme.md,
            jira-story-{fr,en}.md, spec-doc-{fr,en}.md   ← MASTERS (copied from core)
```

> **"MASTER"** = Layer 1 file whose source of truth is `core/`. It is **copied byte for byte**, never rewritten. See the next section.

---

## Consistency with the core (anti-drift)

This is the most important rule in this guide. Team portability relies on Layer 1 being **rigorously identical** in all skills. A dev who masters one project must find exactly the same commands, agents and templates on another one, byte for byte.

### (a) The 34 masters from `core/` are copied verbatim

When creating a skill, we **copy** — without ever adapting them — the **34 master files** from `core/` to `skills/sdd-<stack>/reference/`:

| Origin (`core/`) | Count | Destination (`reference/`) |
|---|---|---|
| `core/commands/*.md` (the 17 SDD commands) | 17 | `commands/` |
| `core/agents/*.md` **except `test-generator.md`** | 4 | `agents/` |
| `core/templates/*.md` | 9 | `templates/` |
| `core/rules/*.md` (`00-sdd-framework`, `02-git-conventions`, `03-security`, `04-code-quality`) | 4 | `rules/` |
| **Total** | **34** | |

These 34 files are not to be touched: no renaming, no rephrasing, no "local improvement". Any evolution happens in `core/` and is then **re-propagated** to all skills (see *Synchronization with the core*).

### (b) Only `test-generator` is adapted to the stack

`test-generator.md` is the **only** one of the 5 SDD agents that depends on the technology (it knows PHPUnit, Jest/Karma, JUnit… and the `*-test` commands actually present in the skill). It is therefore the **only agent excluded** from the hash equality check — it is rewritten for the stack. The 4 other agents remain masters.

### (c) What is specific to the skill (Layer 2)

Everything else — and **only** the rest — is stack-specific:

- The Layer 2 rules: `10-code-conventions.md`, `11-tests-strategy.md`, `12-quality-gates.md`, plus possible stack extras (`doctrine-conventions.md`, `angular-conventions.md`, `node-conventions.md`, `api-contracts.md`, `migration-guard.md`, `legacy-rules.md`, `shared-types.md`, …). Numbering is a **naming convention for authoring only** (`0x` historically Layer 1, `1x` stack rules, extras unnumbered — never renumber existing files): in a deployed project, ownership is resolved by the canonical Layer-1 list and by reference membership, never by the prefix.
- The `<stack>-*` **scaffolding commands** (e.g. `symfony-entity`, `angular-component`, `node-endpoint`).
- The `test-generator` agent (point b).

### (d) Automatic verification: `scripts/audit.sh`

After creating (or modifying) a skill, **always** run:

```bash
bash scripts/audit.sh
```

The audit checks in a single pass:

1. **Structure** — `SKILL.md` present, `reference/{agents,commands,rules,templates}/` non-empty, no `settings.json` (option A: no hooks), skill wired into the installers.
2. **Completeness** — the 17 core commands + the 5 SDD agents present in the skill, the 9 global agents present.
3. **Ghost references** — every cited rule / command (`.claude/rules/X.md`, `.claude/commands/X.md`) actually exists.
4. **Delegations** — `plan-architect` does cite `/sdd-plan`; `test-generator` cites only `*-test` commands actually present in the skill.
5. **Docs** — every declared command count equals the computed one (`ls core/commands/*.md | wc -l` is the source of truth); machine-enforced for the declaration grammar *a number followed by up to two qualifiers among `universal`/`SDD`/`core`/`existing`, then `command(s)`/`commande(s)`* — other phrasings (`Command count: N`, spelled-out numerals) remain a semantic rule (see the Known-Limits Register). Universal command bodies carry no **explicit version token** (`vX.Y` or `X.Y.Z`; the two migration sections §0/§0b of `sdd-upgrade.md` excepted) — release narrative without a version token remains a semantic rule (register). Skill documented in `skills/README.md` (each skill must appear inside the `## Decision tree` block itself), the canonical current-version carriers (listed below) cite the current `VERSION` as an exact whole token (delimited by non-version characters: `11.8.30`, `1.8.30`, `1.8.3.1` and `1.8.3-beta` all fail for `1.8.3`), `CHANGELOG.md` has a `## [VERSION]` entry (a matching git tag is expected — non-fatal notice, ZIP/shallow consumers have no history); anatomy↔template sync (every `## ` section of `core/templates/{spec,plan,tasks}.md` appears in the matching anatomy of `00-sdd-framework.md`); write-step↔template sync (every `#### ` block of a command's "Write" step names `Frontmatter` or a real template section); Layer 1 stays stack-agnostic (`00-sdd-framework.md` names none of the technologies this guide forbids); every file in `core/commands/` is named in this guide's command list (anchored match — a missing short command name is not covered by a longer one that starts with it).
6. **Anti-drift (hash equality)** — every `core/` master is **byte-identical** in the 6 skills, **`test-generator` excepted**; and the groups shared between skills of the same family remain identical (`angular-*` commands/rules between `sdd-symfony-angular`, `sdd-angular-node` and `sdd-java-angular`; `symfony-*` commands/rules between `sdd-php-symfony` and `sdd-symfony-angular`; `java-*` commands + `jpa-conventions` rule between `sdd-java-backend` and `sdd-java-angular`). The hash tool is resolved at startup (`md5sum`, BSD `md5`, `openssl md5` or `shasum -a 256`); if none is available the audit aborts rather than passing blind.

The output must remain `✅ AUDIT OK`. Any drift of a master triggers a `✗ … differs from core/ (drift)`.

The **canonical current-version carriers** — the documents that, by design, state the toolkit's current version — are the list below. `scripts/audit.sh` derives this list verbatim (literal repo-relative paths; an empty list or a carrier missing on disk fails the audit) and guarantees those files cite `VERSION` exactly. Any other document is outside that deterministic guarantee: version-looking numbers elsewhere (stack versions in Layer 2 rules, CHANGELOG history, the `/sdd-upgrade` rename map) are legitimate and not checked against `VERSION`, and whether a non-carrier may state a current version at all remains a semantic rule enforced by human review.

- Current-version carrier: "README.md"
- Current-version carrier: "INSTALL.md"

The **stack-purity vocabulary** below is the canonical, machine-enforced list of test-framework names per stack: a skill may name only the frameworks of its own stack(s), so `scripts/audit.sh` derives from these lines and checks each skill's `test-generator.md` and `11-tests-strategy.md` against the vocabulary of every stack the skill does **not** declare in its membership line. A stack may appear in the vocabulary without belonging to any skill (`python`): its names are then out-of-stack everywhere. The vocabulary is **finite by design** — unknown or future framework names remain a semantic rule enforced by human review (see the Known-Limits Register). Entries are letters and spaces only (they are matched with word boundaries, case-insensitively).

- Stack test vocabulary (php): "PHPUnit"
- Stack test vocabulary (js): "Jest", "Vitest", "Playwright", "Cypress", "Jasmine", "Testing Library", "Supertest"
- Stack test vocabulary (java): "JUnit", "Mockito"
- Stack test vocabulary (python): "pytest"
- Skill stacks: sdd-php-backend = php
- Skill stacks: sdd-php-symfony = php
- Skill stacks: sdd-angular-node = js
- Skill stacks: sdd-symfony-angular = php, js
- Skill stacks: sdd-java-backend = java
- Skill stacks: sdd-java-angular = java, js

### Known-Limits Register

**Consumer: whoever audits this repository next.** A finding is *new* only if it is absent from this register; an entry here is an accepted, documented boundary — challenge it explicitly if you disagree, do not re-report it as a fresh defect. An entry is legitimate only when a deterministic check would be impossible or would cost more in false positives than it buys; if an entry could reasonably be enforced, fix it instead of adding it here. Every entry carries a revisit trigger — "never" is not one.

| Net | Machine-enforced boundary | Known blind spot | Why accepted + revisit trigger |
|---|---|---|---|
| count declarations | the declaration grammar: number + up to two qualifiers (`universal`/`SDD`/`core`/`existing`) + `command(s)`/`commande(s)`, compared to the computed `ls core/commands/*.md \| wc -l` | other phrasings: `Command count: N`, spelled-out numerals (`sixteen commands`) | chasing phrasings is an unwinnable enumeration race; the grammar covers every phrasing that occurs in this repo. Revisit when a doc introduces a new count phrasing the grammar misses — then extend the grammar to it. |
| version narrative | explicit version tokens (`vX.Y`, `X.Y.Z`) in universal command bodies, `sdd-upgrade.md` §0/§0b excepted | release narrative without a token ("added in the previous release") | narrative detection needs semantics, not a pattern; any regex would flood false positives. Revisit if a tokenless release narrative actually ships in a command. |
| stack-agnostic | the canonical 19-name `No mention of` list | other framework names (React, Vue, Laravel, pytest…) and names colliding with ordinary English (`Express`), which can never be substring-enforced | the enumeration is finite and covers what can leak from this toolkit's six stacks. Revisit when a new supported stack is added, or when a Layer 1 rule is caught naming an unlisted technology in review. |
| generated trailers | the canonical `Forbidden trailer` list of `02-git-conventions.md` (4 entries) | a future formatting variant not yet listed | the prose prohibition is open-ended by design; the list is extended as variants are observed. Revisit whenever a new trailer variant is seen in the wild — add it to the list. |
| version carriers | the declared carriers (`README.md`, `INSTALL.md`) cite `VERSION` as an exact whole token | whether a NON-carrier may state a current version at all | that is a different rule needing its own marker grammar; today non-carriers state no current version by design. Revisit if a stale current-version claim in a non-carrier actually misleads a consumer — then define the marker and its net. |
| stack purity | the canonical per-stack test vocabulary above (php/js/java/python) | unknown or future framework names outside the vocabulary | the vocabulary is finite by design; enumerating all frameworks in existence is the race this series ended. Revisit when a new supported stack is added or a new framework appears in a skill's own Layer 2 rules. |
| CI pipeline exclusion | GitLab-shaped markers (shipped `*.yml`, `stages:`, `# .gitlab-ci.yml`, indented `stage:`) | a GitHub-Actions or Jenkins pipeline embedded in a `.md` | the toolkit was only ever GitLab-oriented, and the boundary is stated next to the net. Revisit if the toolkit targets another CI platform. |
| ghost references (§3b/3c) | every cited `.claude/rules\|commands/X.md` exists globally (in core or any skill) | per-skill resolvability: a file cited by one skill but existing only in another passes | per-skill checking false-positives on legitimate cross-stack illustrations (e.g. `sdd-upgrade.md`). Revisit if a deployed project hits a dangling per-skill reference in practice. |
| delegations (§4) | `plan-architect`/`test-generator` description-line citations (`/sdd-plan`, `/X-test`) exist | prose citations elsewhere in agent bodies (covered only by the global §3c net) | the description line is where Claude Code routes delegation; body prose is illustrative. Revisit if a body-level citation ever misroutes a real delegation. |

---

## Strict rules for stack skills

### ❌ Prohibitions

**Never rename or redefine the 17 universal SDD commands**:
`/sdd-start`, `/sdd-spec`, `/sdd-clarify`, `/sdd-spec-check`, `/sdd-plan`, `/sdd-tasks`, `/sdd-implement`, `/sdd-verify`, `/sdd-review`, `/sdd-mr`, `/sdd-archive`, `/sdd-status`, `/sdd-hotfix`, `/sdd-upgrade`, `/sdd-changelog`, `/sdd-revert`, `/retro-spec`.

These commands belong to Layer 1. Modifying them breaks team portability across projects.

**Never alter a master** (see *Consistency with the core*): the 34 masters are copied verbatim. The only allowed adaptation on the agents side is `test-generator`.

**Never pollute the methodology with tech**:
- No mention of "PHPUnit", "Jest", "JUnit", "Karma", "Jasmine" in `00-sdd-framework.md`.
- No mention of "Symfony", "Angular", "Spring", "Doctrine", "Hibernate", "NestJS", "Fastify" in the process files.
- No mention of "composer", "npm", "gradle", "npx", "Maven", "Flyway", "Liquibase" in the process files — package-manager, build-tool and migration-tool names belong to Layer 2, where they are actually written (each skill's 10/11/12 rules).

These `No mention of` lines are the **machine-enforced subset** of the stack-agnostic rule: `scripts/audit.sh` derives its forbidden-name list from them verbatim, so a name is only caught automatically once written here. The wider rule — Layer 1 names nothing stack-dependent, whatever the technology — remains a semantic rule enforced by human review. A name earns its place here when it is genuinely likely to leak from this toolkit's six stacks, not by enumerating every framework in existence (so "React", "Vue", "Laravel" or "pytest" stay semantic-only). Matching is substring-based and case-insensitive: a name that collides with ordinary English words — "Express", which "expressed" or "expression" would match — cannot join the list and also stays semantic-only.

**Never include business skills** in a stack skill:
- Project-specific skills (e.g. SSO, SOAP, billing) are project-specific, not stack-specific.
- They belong to Layer 3.

### ✅ Permissions

- Freely define the stack's code rules (`10-code-conventions.md`).
- Define the test strategy and execution commands (`11-tests-strategy.md`).
- Define the quality gates (`12-quality-gates.md`) and the stack extras.
- Add auxiliary scaffolding commands (`<stack>-entity`, `<stack>-component`, etc.).
- Adapt `test-generator` to the stack.
- Add stack-specific code templates in `templates/`.

---

## Granularity of auxiliary commands

Scaffolding granularity is a **design choice**. Two families exist; pick one and apply it consistently across the team's skills.

### Option A — Coarse granularity

One command per business layer (scaffold entity + service + controller + tests in one shot). Relevant when you want to generate a vertical slice in one call.

### Option B — Fine granularity

One command per artifact type. **This is the option chosen in all the toolkit's current skills**, because it composes better with the `/sdd-implement` loop (one task → one artifact → one local commit):

| Skill | Actual scaffolding commands |
|---|---|
| `sdd-php-symfony` | `/symfony-entity`, `/symfony-service`, `/symfony-controller`, `/symfony-test` |
| `sdd-symfony-angular` | `/symfony-entity`, `/symfony-service`, `/symfony-controller`, `/symfony-test`, `/angular-component`, `/angular-service`, `/angular-test`, `/api-contract` |
| `sdd-angular-node` | `/angular-component`, `/angular-service`, `/angular-test`, `/node-endpoint`, `/node-service`, `/node-test`, `/api-design`, `/contract-check` |
| `sdd-php-backend` | `/php-class`, `/php-test`, `/extract-class` |
| `sdd-java-backend` | `/java-entity`, `/java-service`, `/java-controller`, `/java-test` |
| `sdd-java-angular` | `/java-entity`, `/java-service`, `/java-controller`, `/java-test`, `/angular-component`, `/angular-service`, `/angular-test`, `/api-contract` |

> All scaffolding commands are **tools**: they read `spec.md` / `plan.md` to draw from their content, but **never replace** `/sdd-implement`.

---

## `SKILL.md` template

A stack skill's `SKILL.md` must:

1. Declare the scope (when to use it / when not to use it) and the detection triggers (e.g. `composer.json` contains `symfony/framework-bundle`).
2. Describe the deployment from `reference/` to `.claude/`.
3. Detect brownfield / greenfield mode and adapt to it.
4. Check the presence of the 34 masters (otherwise, refuse and point back to the core).

Typical skeleton of the installation flow:

```markdown
# SDD Framework — <Stack>

> <Stack> variant of the SDD toolkit. Deploys reference/ into .claude/.

## Phase 0 — Common core verification
Check the presence of the Layer 1 masters:
- .claude/rules/00-sdd-framework.md, 02-git-conventions.md, 03-security.md, 04-code-quality.md
- the 17 commands .claude/commands/sdd-*.md (+ retro-spec.md)
- the templates .claude/sdd/_template/*.md
If any is missing: refuse and install Layer 1 first.

## Phase 1 — <Stack> Discovery
[Stack detection + at most 3 technology-focused questions — no process questions]

## Phase 2 — Proposed structure
[List of Layer 2 files to add — the masters are already in place]

## Phase 3 — Generation
[Sequential generation of the Layer 2 files, one by one]

## End
✅ <Stack> skill installed.
Next step: add the project's business skills in .claude/skills/ (Layer 3).
```

---

## Quality checklist for a stack skill

Before publishing a skill, check:

- [ ] The **34 masters** from `core/` are copied verbatim into `reference/` (verified by `audit.sh §6`)
- [ ] The **17 universal SDD commands** are neither renamed nor redefined
- [ ] Only `test-generator` is adapted to the stack; the 4 other SDD agents remain masters
- [ ] The granularity of the auxiliary commands is consistent with the team's other skills
- [ ] The Layer 2 rules are technical only (no business, no process)
- [ ] The auxiliary commands read `spec.md` / `plan.md` and do not replace `/sdd-implement`
- [ ] No `settings.json` (option A — no hooks)
- [ ] The skill is wired into `install.sh` / `install.ps1` and documented in `skills/README.md`
- [ ] `bash scripts/audit.sh` returns `✅ AUDIT OK`

---

## Example: creating the PHP/Symfony skill

### Discovery (Phase 1)

Focused questions:
1. PHP / Symfony / Doctrine versions?
2. Architecture (DDD, standard Symfony, hexagonal)?
3. Auth bundles (lexik/jwt, symfony/security)?
4. PHPStan level?
5. Quality tools (CS-fixer, Rector)?

### Generation (Phase 3) — Layer 2 only

The 34 masters are already copied from `core/`. Only the stack-specific files are generated:

```
reference/rules/
  10-code-conventions.md       ← PHP 8.x strict_types, PSR-12, Symfony conventions
  11-tests-strategy.md         ← PHPUnit, WebTestCase, fixtures, conventions
  12-quality-gates.md          ← PHPStan level X, CS-fixer, Rector, make quality
  doctrine-conventions.md      ← stack extra
  migration-guard.md           ← brownfield extra

reference/commands/            ← fine granularity (option B)
  symfony-entity.md            ← scaffolds a Doctrine entity + mapping
  symfony-service.md           ← scaffolds an application service
  symfony-controller.md        ← scaffolds a controller + route
  symfony-test.md              ← scaffolds the tests from the spec

reference/agents/
  test-generator.md            ← adapted: PHPUnit, WebTestCase, fixtures
```

### What is NOT in the skill

- Project-specific skills (e.g. SSO, SOAP, billing) → Layer 3 (project)
- Project-specific code templates → project
- Business entity names (e.g. `User`, `Order`) → project
- Connections to specific tools (Jira) → core or project

---

## Existing skills and extension leads

### Already packaged (6 skills)

| Skill | Stack | Typical projects |
|---|---|---|
| `sdd-php-backend` | Pure PHP (no framework) | Legacy, PHP scripts & tools |
| `sdd-php-symfony` | PHP + Symfony + Doctrine | Back-office, business API |
| `sdd-symfony-angular` | Symfony + Angular | Full-stack application |
| `sdd-angular-node` | Angular + Node.js/Express | Full-stack application (Node) |
| `sdd-java-backend` | Java + Spring Boot + JPA | Business API, batch backend |
| `sdd-java-angular` | Spring Boot + Angular | Full-stack application (Java) |

### Leads for new stacks

1. `sdd-python-django` — Python / Django projects
2. `sdd-go` — Go services

For each: copy the 34 masters, write Layer 2 (rules + scaffolding + `test-generator`), wire the installers and `skills/README.md`, then validate with `audit.sh`.

---

## Distribution

As the skills mature, several distribution paths are possible:

### Phase 1 — Skills (current state)

Each stack is a skill installed by symlink via `install.sh` / `install.ps1`, which deploys `reference/` into `.claude/`.

### Phase 2 — Repo templates

Create a `cookiecutter` or `degit` per stack that scaffolds the `.claude/` structure directly.

### Phase 3 — Central registry

Distribute the skills via a shared team registry.

### Phase 4 — Claude Code plugin

If a plugin system is available, package the toolkit as an installable plugin.

---

## Synchronization with the core

When a `core/` master evolves (new Layer 1 version):

1. Modify the file in `core/` (single source of truth).
2. **Re-propagate** the master verbatim to the 6 skills (`reference/…`).
3. Run `bash scripts/audit.sh`: section 6 must turn green again (hash equality restored).
4. User projects apply the update via `/sdd-upgrade` (updates Layer 1 without touching Layers 2/3).

As long as the core does not change, the skills remain valid indefinitely. As long as the audit is green, team portability is guaranteed.
