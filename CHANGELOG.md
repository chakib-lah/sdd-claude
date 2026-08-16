# Changelog — SDD Claude

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
