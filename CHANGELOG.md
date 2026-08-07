# Changelog — SDD Claude

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
