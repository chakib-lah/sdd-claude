# Changelog — SDD Claude

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
