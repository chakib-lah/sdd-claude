---
description: SDD maintenance — stable bootstrap that loads and executes the current toolkit upgrade procedure
---

# /sdd-upgrade — stable bootstrap (shim)

**This command contains no upgrade business logic — by design.** It only locates the current toolkit reference and hands execution to the canonical upgrade procedure that ships with it. Layer synchronization, ownership triage, project-truth preservation, migrations, decisions, verification and the version marker are all owned by that procedure, never by this file. This file is deliberately small and version-stable: it is deployed identically as the project-local `.claude/commands/sdd-upgrade.md` and as the global `~/.claude/commands/sdd-upgrade.md` bootstrap, and behavior never depends on which of the two was invoked.

## Bootstrap — the only thing this command does

1. **Determine the project's SDD skill.** Read the project's stack evidence the same way the installers do (build manifests discovered from the repository — e.g. `composer.json`, `build.gradle`/`pom.xml`, `package.json`, `angular.json`) and select the matching skill among `sdd-php-backend`, `sdd-php-symfony`, `sdd-symfony-angular`, `sdd-angular-node`, `sdd-java-backend`, `sdd-java-angular`. If the evidence is ambiguous, ask the user which SDD skill the project uses — never guess.
2. **Resolve the current reference**: `~/.claude/skills/<skill>/reference/`. If no installed skill is found, ask the user for the path to the sdd-claude toolkit, then use `<toolkit>/skills/<skill>/reference/`.
3. **Load the canonical procedure.** Read `<reference>/upgrade/sdd-upgrade-procedure.md` **in full, as instructions** — not as a file to diff or deploy. If that file does not exist, the installed toolkit predates this architecture: ask the user to update the global toolkit (`git pull` in the toolkit, then `./upgrade-global.sh` — or `.\upgrade-global.ps1` on Windows) and **stop**. Never fall back to embedded upgrade logic: this file has none.
4. **Hand off.** Set `CURRENT_REFERENCE_PROCEDURE_ACTIVE = YES` — a runtime state of this invocation only, never persisted to disk or to any project file — and execute the loaded procedure from its beginning. From that point the procedure is the **sole** normative source of upgrade semantics for this run.

## Invariants

- **No hybrid execution.** Once the procedure is loaded, every rule, gate, decision, postcondition and output contract comes from it alone: this shim adds nothing, filters nothing and overrides nothing.
- **Idempotence.** If `CURRENT_REFERENCE_PROCEDURE_ACTIVE` is already `YES` when this file is read, the bootstrap already happened: do not re-enter it, do not re-read the procedure, do not restart the run.
- **Stability.** This shim carries no version-specific knowledge; upgrading the toolkit changes the procedure it loads, never the way it loads it.
