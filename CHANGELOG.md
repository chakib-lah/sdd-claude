# Changelog — SDD Claude

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
