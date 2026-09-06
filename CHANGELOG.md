# Changelog — SDD Claude

## [1.17.0] — 2026-09-06

Semantic ownership release, validated on real production projects: effective Git policy, canonical working language, SDD-metadata-free source code, the spec/plan responsibility boundary, and deterministic `/sdd-upgrade` behavior.

### Changed

- **Effective Git policy everywhere** — the universal Git layer owns only the true invariants (English subject, short, subject line only, no `Co-Authored-By` or tool-generated trailer, never `--no-verify`); ticket presence and placement, commit types/scopes, branch patterns and no-ticket formats are project policy resolved through `project-git-workflow.md`. Every commit/branch producer states a semantic intent and formats it through the effective policy. Fresh installers discover the current durable convention from real history and explicit project documentation — a framework example is never promoted to Layer 3, and inconclusive evidence yields a targeted developer question, never an invented policy.
- **Canonical working language** — `project-working-language.md` is an established Layer-3 subject owner declared by all six installers, and `00-sdd-framework.md` defines its scope: project-facing SDD communication uses the declared working language; Git commit subjects and source-code comments stay English under the universal invariants. `/sdd-upgrade` gains a clause-atomic, authority-safe migration for the known legacy `project-language.md` filename: valid working-language clauses migrate verbatim to the canonical file, while a clause that would negate Layer 1/2 (e.g. non-English source comments) raises a `USER_DECISION_REQUIRED` targeted at that clause alone — never silent deletion, preservation or reinterpretation. The language gate is a mandatory main-flow branch of the upgrade, an independent disk-state check verifies the final filesystem before success, and the version marker is written only after convergence.
- **No SDD metadata in application source** — universal source-comment baseline: comments are English, short, explain non-obvious code/domain intent only, and carry no AC, task, ticket or SDD-artifact reference added for traceability; tests are named for the behavior they attest. AC ↔ implementation/test traceability lives in the SDD artifacts and the `/sdd-verify` / `/sdd-review` gates. Migration progress is tracked in the debt document, the issue tracker and the SDD artifacts — never by counting tracking comments in source.
- **Spec = WHAT/WHY, plan = HOW** — the standard `spec.md` loses its technical Design section and gains a Functional behavior section (business rules, user-visible flows, externally observable contracts); `plan.md` becomes the explicit technical-design owner (endpoints, data model and migrations, services and components, class/method placement, impacted files, AC → test mapping). The interview asks for externally observable constraints, never implementation decisions; clarification answers that settle implementation go to planning context; the retrospective spec keeps observed behavior in the spec while implementation discovery and the debt register live in `notes.md`.
- **Deterministic `/sdd-upgrade`** — the unconditional plan confirmation is removed: the plan is displayed for transparency and a deterministic upgrade continues autonomously; `USER_DECISION_REQUIRED` is reserved for genuine non-deterministic ambiguity and freezes only its own artifacts. The `.sdd-version` marker is written LAST, after complete post-upgrade verification. The path-only canonical reference repair distinguishes active from archived feature artifacts: archives and historical prose are never rewritten.

### Fixed

- **Deterministic audit verification** — consistency checks no longer depend on pipeline timing: the same tree yields the same verdict on every run, and the harness enforces that invariant on itself.

---

## [1.16.0] — 2026-09-01

Structural naming and fresh-install semantics release.

### Changed

- **Permanent rule-file naming convention** — `00–09` Layer 1; Layer-2 functional decades (`10–19` fundamentals, `20–29` runtime/backend, `30–39` persistence/ORM, `40–49` frontend/UI, `50–59` API/contracts, `60–69` brownfield/change protection); `project-*` Layer 3. Numbering is human-facing visual classification only: ownership stays resolved by reference membership, and numbers establish no precedence.
- **Canonical Layer-2 path normalization** — the nine pre-decade Layer-2 rule names are renamed to their functional-decade paths across the six skills (pure renames, content preserved); every active reference is repaired by exact path token. `/sdd-upgrade` migrates historical Layer-2 names as selected-skill-scoped entries: a same-named project-owned file in an unrelated skill is never renamed or misclassified, and old/new coexistence follows the single coexistence rule.

### Fixed

- **Fresh installs enforce the ownership and persistence model end to end** — installation proposals label every artifact by its actual owner; detected technical state stays rediscoverable on demand instead of being persisted as project rules; gaps and debt remain reported follow-ups, never silently repaired and never promoted to policy; durable human-owned decisions remain fully eligible for Layer 3.
- **Approval-faithful Layer-3 materialization** — the first displayed proposal is the normalized, approval-ready one (atomic clauses, one disposition and one owner per clause, empty candidates never shown); developer approval freezes the Layer-3 set verbatim; the write phase is transcription plus formatting, never semantic authorship (a rule that seems wrong during rendering stops materialization and goes back for re-approval); written files are verified against the approved records, never against reconstructed intent.
- **Architecturally valid choices only** — an option that would override or negate Layer 1/2 or redefine the selected skill's target baseline is never offered; brownfield preservation keeps existing scope without redefining the target for new work.
- **Evidence-safe discovery** — configuration, generated artifacts, tracked state, workflow and human policy are independent evidence dimensions: an absent generated artifact never proves a capability is unconfigured, and inferences are labeled as risks, never asserted as facts.

---

## [1.15.0] — 2026-08-31

Java backend Layer-2 stabilization: `sdd-java-backend` adopts the discovery-aware ownership architecture.

### Changed

- **Root/build/wrapper discovery** — the repository root, backend/build root (nested or top-level, multi-module included), the Gradle/Maven wrapper location and the configured tasks/goals are discovered project facts; operational commands are complete discovered invocations (wrapper location, working directory, module selector, options), and a Maven project never receives a Gradle command.
- **Quality capability vs implementation** — tests, static/style quality, formatting, coverage, build verification and dependency quality remain required capabilities while their implementations are discovered from the build; absences are explicit `PROJECT_TOOLING_GAP`s, and no strictness profile can turn a required capability off.
- **Test-suite discovery** — build tool, real test tasks/goals and suite/naming conventions are discovered; standard single-task projects and alternate integration-test conventions work without invented tasks.
- **Engine-neutral integration testing** — integration tests exercise a real or representative instance of the project's database engine via the discovered strategy; no specific database infrastructure is imposed universally.
- **Conditional dependency locking** — locking is a discovered project state and a greenfield recommendation; it is never enabled silently during unrelated work.
- **REST-aware API-contract gaps** — a REST backend without a machine-readable contract mechanism is an explicit gap; non-REST backends (batch, workers, consumers) are contract-capability not-applicable — no false gap, no forced tooling.

---

## [1.14.0] — 2026-08-31

Java/Angular Layer-2 stabilization: `sdd-java-angular` adopts the discovery-aware architecture, verified against real Gradle/Spring/Angular project shapes.

### Changed

- **Root/build/test discovery** — backend and frontend roots, wrapper location, module structure, actual test tasks and suite conventions are discovered; commands, gates and hooks use a repository-root-based coordinate system, and change predicates handle both nested roots and a backend at the repository root.
- **Java quality capability discovery** — required capabilities with discovered implementations; only configured checks are invoked, absences are explicit gaps.
- **Angular runner alignment** — Vitest is the modern target runner, Karma/Jasmine a supported brownfield state, Jest honored where configured; test and gate commands go through the project's discovered scripts.
- **Provider-neutral API contract workflow** — provider-generated and project-owned OpenAPI contracts are both valid sources; `/api-contract` discovers the provider, exports candidate-first, keeps check mode non-destructive, and never installs tooling silently. Whether the generated contract is tracked in Git is a project fact, never a forced snapshot.
- **Shared Java scaffolding** — controller scaffolding follows the project's discovered contract mechanism; test scaffolding discovers wrapper, tasks and suite convention before generating or running anything, and executes exactly the class it generated.

---

## [1.13.0] — 2026-08-30

Symfony/Angular Layer-2 stabilization following the discovery-aware model.

### Changed

- **Discovery-aware roots and tooling** — roots, versions, suites, wrappers, lint/strictness/formatter configuration and CI topology are project facts read from the repository; Layer 2 stays byte-identical across projects, and workflows never assume a fixed monorepo layout.
- **Modern Angular target** — standalone components, signals, `inject()`, strict TypeScript; Vitest as the modern target runner with Karma/Jasmine as a supported brownfield state; existing legacy states are preserved migration states with visible gaps, migrated only in dedicated tasks. Async-test guidance follows the discovered runner.
- **Backend quality baseline** — PHPUnit, PHPStan, Rector and PHP-CS-Fixer remain required capabilities with discovered parameters; missing tooling is a `PROJECT_TOOLING_GAP`.
- **Provider-neutral API contract model** — a machine-readable OpenAPI 3.x contract with automated Angular type synchronization stays the required full-stack capability; the provider, serializer, contract location and generator are discovered. A valid project-owned hand-written contract is an accepted source of truth; exports go to a temporary candidate compared before any update, and the pre-commit hook fails on staleness instead of overwriting the tracked contract.

---

## [1.12.0] — 2026-08-30

PHP/Symfony Layer-2 stabilization, validated on real brownfield migration projects.

### Changed

- **Project parameters are discovered, never edited into Layer 2** — tool versions, layouts, suite names, execution commands, architecture shape and quality levels are project facts read from the repository or durable Layer-3 specializations; the reference files stay byte-identical across projects.
- **Required capabilities stay required** — PHPUnit, PHPStan, Rector and PHP-CS-Fixer keep a three-state contract: present → discover and enforce; below target → report the gap, tighten only in a dedicated quality change; absent → `PROJECT_TOOLING_GAP`, never a silent install.
- **Greenfield keeps strong defaults** — recommended structures apply only when no project structure or decision exists.
- **Layer 3 specializes, never negates** — project rules may specialize paths, levels and context; they cannot cancel a universal requirement.

---

## [1.11.0] — 2026-08-30

Canonical Layer-1 path normalization with a safe structural migration.

### Changed

- **Final Layer-1 order 00/01/02/03** — the Git, security and code-quality rules close the numbering gap left by the retired constitution slot; all active consumers reference the new canonical paths.
- **Version-agnostic structural migration** — `/sdd-upgrade` detects legacy Layer-1 shapes structurally, plans renames write-free, preserves project truth before convergence (verification failure stops before any destructive step), and resolves old/new coexistence through one deterministic rule (proven redundancy → converge; project truth → preserve first; ambiguity → user decision).
- **Constitution safety** — legacy constitution carriers are resolved by a single mutually exclusive and exhaustive decision model before the `01` slot is reused: an empty scaffold is removed, meaningful content migrates verbatim to `project-constitution.md`, any conflict or ambiguity is a user decision — never a merge, never a guess.
- **Path-only canonical reference repair** — after convergence, eligible preserved active artifacts have dangling old canonical path tokens repaired by exact, byte-verified token substitution; historical feature artifacts, archives and retrospectives are never rewritten, and a stale path inside a freshly installed reference copy is a source defect, never a local patch.

---

## [1.10.0] — 2026-08-30

Strict framework / skill / project ownership: every deployed rule has exactly one owner, making upgrades deterministic.

### Changed

- **Ownership model** — Layer 1 is the exact canonical rule set (framework-owned, byte-equal to the reference after upgrade); Layer 2 is every other rule or stack command the selected skill ships, resolved by reference membership, never by filename prefix; everything else is Layer 3, project-owned, never byte-replaced. Ownership is distinct from applicability: conditional skill artifacts (e.g. brownfield-only) are evaluated with the skill's own mode detection, and expected absences are never drift.
- **Active constitution retired** — the project constitution becomes a Layer-3 file, `project-constitution.md`; no skeleton is deployed to new projects, and `/sdd-upgrade` migrates meaningful legacy carriers verbatim.
- **Effective Git policy** — the universal Git rule declares its invariants, defaults and project-configurable extension points; a single Layer-3 Git rule may configure them, and every command resolves messages and branches through that policy instead of hard-coding formats.
- **`/sdd-upgrade` rewritten around ownership** — inventory → ownership resolution → divergence triage with typed actions → project truth preserved and verified before any replacement → Layer 2 updated from the selected skill → three exhaustive honest outcomes (`UPDATED`, `UPDATED PARTIALLY`, `UPDATE INCOMPLETE`).
- **Fresh installation no longer mutates Layer 2** — detected project facts are read on demand, persisted as durable Layer-3 context, or reported as diagnostics; Layer 2 stays byte-identical to the reference.

### Compatibility

Existing projects keep working; the new ownership takes effect at their next `/sdd-upgrade`.

---

## [1.9.0] — 2026-08-29

Lifecycle hardening: existing gates become stricter so commands can no longer silently consume artifacts whose schema predates the current contract. Not fully backward-compatible for projects carrying legacy artifacts.

### Changed

- **`/sdd-verify` blocks malformed or duplicated task identifiers** — the canonical shape is `T` + digits (zero-padded, stable for life); legacy or duplicated identifiers block the gate with a safe manual-migration procedure. Numeric gaps are tolerated.
- **Hotfix verification validates the real Test→Fix Git relationship** — both commits must resolve, be distinct, correctly ordered and reachable; merged production history is never rewritten to satisfy the gate.
- **Complete canonical `AC-N` coverage required** — `/sdd-spec-check` and `/sdd-review` refuse specs with unidentified or mixed acceptance criteria rather than silently skipping them; migration preserves wording, meaning and order, and remediation follows each gate's own prerequisites.
- **`.claude/sdd/README.md` becomes a static guide** — live feature state is derived from the feature folders and frontmatter by `/sdd-status`; the old duplicated index is migrated safely, custom project prose preserved.
- **Honest upgrade outcomes** — residual divergences are classified after the apply, and any warning-class residual or pending manual review yields a partial result, never an unconditional success.

---

## [1.8.0] — 2026-08-29

The three-layer model gains its code-quality slot, upgrades gain layer triage, and the repository becomes publicly distributable.

### Added

- **`03-code-quality.md` (Layer 1)** — generic, stack-agnostic development best practices (debug leftovers, dead code, swallowed exceptions, non-regression tests, duplicated business logic, backward compatibility, quality bypasses, test honesty, data migrations), loaded while code is written, checked by the reviewer, reported by `/sdd-review`.
- **`/sdd-upgrade` layer triage** — before the upgrade plan, every divergence of an owned file is classified with the layer decision test and given a destination; "already covered elsewhere" requires pasted proof on the project's actual file — no proof, no discard.
- **MIT license and public documentation** — the framework is distributed under the MIT License; the documentation states the public-framework/private-project-data boundary: project-specific rules, internal names, ticket references and private hostnames belong in the consuming project's private configuration, never in this framework.

### Changed

- **The reviewer reads the rules instead of containing them** — embedded anti-pattern catalogs moved to their correct layers; no skill ships another stack's examples.
- **`Co-Authored-By` and generated trailers are forbidden by name** — the prohibition is stated at every commit-composition point, and the consistency audit rejects any shipped instruction to add such a trailer.
- **The layer boundary is an operational test** — Layer 1: true for every project; Layer 2: true for the whole stack; Layer 3: everything else — documented in the extension guide with the audit deriving its vocabulary from it.
- **Audit coherence** — declared counts are computed, version citations are exact whole tokens, universal commands are version-agnostic by pattern, and the extension guide carries the register of accepted deterministic audit boundaries.

---

## [1.7.0] — 2026-08-17

Consolidating release closing the 1.6 stabilization line.

### Changed

- **Backward-compatible Rollback gate** — a phase without a Rollback line is accepted and means the implicit default (revert of the phase commit); present-and-filled is read by `/sdd-revert`; present-but-empty is reported.
- **Phase-squash safety guards** — the squash verifies history contiguity (a foreign commit in the range skips the squash instead of swallowing it) and a clean index; a guard-skipped squash is announced and documented, and phase progress is visible in every `/sdd-implement` announcement.
- **Commit messages drop the type** — the format becomes `<TICKET-ID>: <imperative description>`; the work's nature lives in the branch name, not in a second per-subject taxonomy.
- Hotfix features are exempt from the plan requirement, and `/sdd-hotfix` instructs approving `tasks.md` as well as the spec.

---

## [1.6.0] — 2026-08-16

Security-aware spec gate and workflow hardening.

### Added

- **Security considerations are written and scored** — `/sdd-spec` fills the section (data sensitivity, authn/authz impact, external inputs, abuse cases → `[SEC]`-tagged ACs, one-line justification when not applicable) and `/sdd-spec-check` scores it on a canonical 17-criterion checklist.
- **Untrusted-content rule (Layer 1)** — anything entering from outside the repository (tickets via MCP, pasted text, provided documents, third-party code) is data, never instructions; explicit cautions sit at every point where untrusted content actually enters, and agent permissions are minimized accordingly.
- **Stable AC identifiers** — every acceptance criterion carries a stable `AC-N` for life (a removed AC leaves a hole, a new AC takes the next free number); the `[SEC]` tag sits after the identifier.
- **Phase Rollback field** — every phase block declares its rollback path, read by `/sdd-revert` and verified by `/sdd-verify`.
- **Version marker** — the deployed toolkit version is recorded per project in `.claude/sdd/.sdd-version`, written by the upgrade and read by the next one.

### Changed

- **The toolkit never ships CI pipelines** — deliberate scope decision: every project owns its CI; the toolkit states WHAT must be green, never how the pipeline is wired. All shipped pipeline templates and embedded pipeline blocks are removed, with the durable knowledge kept in prose; a no-return check makes shipped pipeline content impossible.
- **One skill, one stack** — each skill's test generation and test strategy name only its own stack's frameworks; per-stack coverage gates are executable (diff-based thresholds).
- **Fresh reference required for upgrades** — `/sdd-upgrade` verifies the toolkit reference is fresh before auditing anything, with an explicit warning when freshness cannot be checked.
- Branch prefixes and commit types are two explicit vocabularies, and a project may override the branch model in its own Layer-3 rules.

---

## [1.5.0] — 2026-08-16

### Added

- **Two Java skills** — `sdd-java-backend` (Java + Spring Boot, JPA/Hibernate, Flyway: conventions, test strategy, quality gates, entity/service/controller/test scaffolding) and `sdd-java-angular` (Spring Boot + Angular full-stack with OpenAPI contract synchronization); the toolkit now ships 6 skills.
- **`spring-java-expert` global agent** — modern Java and Spring Boot guidance (9 global agents now).

### Changed

- Modernized shared Angular conventions: zoneless change detection, signals-first guidance, built-in control flow, Vitest as the default runner for new projects, incremental migration ladder for legacy projects.

### Fixed

- **Agents are invocable everywhere** — every agent's tool declaration uses the recognized bracketed capitalized form, enforced by the audit.
- **Installers and updaters never destroy user data** — a real directory found at a skill path is backed up, never deleted; divergent global agents are kept and reported, with an explicit `--force` to overwrite.
- Portable audit hashing (hard failure when no hash tool exists), release-coherence checks, and retroactive release tags.

---

## [1.4.0] — 2026-08-12

### Added

- **`/retro-spec` business-facing exports** — optional deliverables derived from a retrospective spec: a ticket-ready story export and a functional SPEC document, with an export-only mode, a user-provided document format option, and consistent numbering across deliverables.
- **Four export templates** in two language variants, deployed with the other templates and verified by the audit.

### Changed

- **`/retro-spec` hardened** — flexible targets (module, screen, route or file), an intent-only question protocol (oral answers are never promoted to facts), a self-contained spec, and kebab-case normalization.
- **Retrospective lifecycle wired across the framework** — status display, archive behavior and upgrade checklists understand retrospective features; project-own export templates are never touched.

### Security

- Ticketing MCP access is read-only for retrospective analysis; exports carry no secrets, credentials, environment URLs or personal data and require human re-read before diffusion.

---

## [1.3.0] — 2026-08-07

### Added

- `/sdd-upgrade` audits the SDD agents; developer-owned agents are never touched.
- `upgrade-global.sh` / `upgrade-global.ps1` — update the global `~/.claude` after a toolkit update: repair skill symlinks, refresh global agent copies, never overwrite customized copies silently.

### Changed

- **Rules renumbered — first digit = layer** (0x = Layer 1 methodology, 1x = Layer 2 stack); `/sdd-upgrade` gains a structural migration that renames a project's files, content untouched.

---

## [1.2.0] — 2026-08-07

### Changed

- **One commit per implementation phase** — tasks are grouped under phase headings; `/sdd-implement` keeps one local commit per task and squashes each phase into a single commit before push; verification, revert, review and MR flows adapted. Hotfixes keep their red-test commit visible.
- **Commit messages are subject-line only** — no body, no generated signature.
- **Minimal MR body** — context and changes only; the details stay in the SDD artifacts.

---

## [1.1.0] — 2026-07-19

Consistency, security hardening, and three new Layer 1 capabilities.

### Added

- `/sdd-clarify` — dedicated ambiguity-resolution pass on the spec before approval.
- `/sdd-revert` — rollback command driven by the commit SHAs tracked in `tasks.md`.
- Project constitution skeleton (team-ratified durable principles), scored by `/sdd-spec-check` and enforced by `/sdd-review`.

### Changed

- `/sdd-review` requires a passing `/sdd-verify`; task state markers are formalized; the canonical AC format is normalized everywhere.

### Security

- Checksum-verified installer downloads in the documented CI examples, unpredictable temporary paths, and an explicit prompt-injection caution when reading untrusted repository content.

---

## [1.0.0] — 2026-07-05

First stable release of the framework.

- Complete framework in English: all commands, rules, agents, templates and skills.
- Bilingual triggers: skills and agents respond to English and French trigger phrases.
- Security rule and security checks in `/sdd-verify`.
- Hardened install and audit scripts.
