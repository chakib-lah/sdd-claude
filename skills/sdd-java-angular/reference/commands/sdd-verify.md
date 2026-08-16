---
description: SDD technical gate — checks tests, quality, completeness before push
---

# /sdd-verify

**SDD technical gate**: mechanically verify that the implementation is ready to push (tests green, quality gates OK, completeness).

## Blocking prerequisites

- An active SDD feature must exist
- `tasks.md` must exist with `status: approved`

## Steps

### 1. Detect the active feature

Identify the feature from the Git branch.

### 2. Check task completeness

Read `.claude/sdd/<feature>/tasks.md` and verify that **all** tasks are `done` (`- [x]`).

For each `done` task, verify that the `**Commit SHA**` field is filled in.

For each implementation phase whose tasks are all `done`, verify that the `**Phase commit SHA**` field is filled in (i.e. the phase was squashed by `/sdd-implement` step 11b). Accepted exceptions: a phase marked `*(not squashed — commits pushed mid-phase, see notes.md)*` **with** the incident documented in `notes.md`, and **hotfix features** (`type: hotfix` frontmatter or `hotfix/` branch), which are exempt from the squash — for them, only check the per-task `Commit SHA` fields. A `tasks.md` without `### Phase` headings counts as one implicit phase.

**If a task is not `done`, has no SHA, or a completed phase is not squashed**:

```
❌ Incomplete tasks or phases:
   - T00X: status pending
   - T00Y: status done but SHA missing
   - Phase N: complete but not squashed (Phase commit SHA empty)

Action: finish the tasks via /sdd-implement (which performs the phase squash) before re-running /sdd-verify.
```

Once `/sdd-verify` has recorded its verdict, **never re-squash a phase it has already verified**: the review gate compares HEAD against the verified commit, and rewriting verified history would invalidate it. New phases created after the gate (e.g. `Phase N+1: Review fixes` from `/sdd-review`) are squashed normally by `/sdd-implement` — then `/sdd-verify` must be re-run.

### 3. Check that the Git tree is clean

```bash
git status --porcelain
```

If the tree is not clean, list the uncommitted modified files and **refuse**. Everything must be committed before the gate.

### 4. Check the branch

Confirm that we are on the expected feature branch (not on the integration branch). Read `.claude/rules/02-git-conventions.md` for the convention.

### 5. Run all the test suites

Read `.claude/rules/11-tests-strategy.md` (if present) for the list of test suites to run, or detect the project's standard scripts (`make test`, `npm test`, `mvn test`, etc.).

Run each suite and collect the results:

```
Test suite                 | Result
---------------------------|----------
Unit tests                 | ✅ 142 passed
Integration tests          | ✅ 23 passed
Functional tests           | ❌ 1 failure (UserControllerTest::testCreate)
E2E tests                  | ✅ 8 passed
```

### 6. Run the quality gates

Read `.claude/rules/12-quality-gates.md` (if present) for the list of tools to run, otherwise detect the project's tools:

- Static linters (PHPStan, ESLint, mypy, golint, etc.)
- Formatters (php-cs-fixer, prettier, black, etc.)
- Automated refactoring (Rector, etc.)
- Security (SonarQube, Snyk, etc.) if configured
- Test coverage (if a threshold is defined)

```
Quality gate              | Result
--------------------------|----------
PHPStan level 8           | ✅ OK
PHP-CS-Fixer              | ✅ OK
Rector                    | ⚠️ 2 suggestions
Coverage                  | ✅ 87% (threshold 80%)
```

### 7. Run the security gate

Read `.claude/rules/03-security.md` (if present) for the full baseline. At minimum:

- **Dependency audit**: run the stack's audit tool (`composer audit`, `npm audit --audit-level=high`, or equivalent). No unacknowledged high/critical finding — acknowledged findings must be listed in `notes.md` with a remediation date.
- **Secret scan**: scan the diff for credential patterns (`git diff <integration-branch>..HEAD` + `gitleaks`/`trufflehog` if available, otherwise grep for obvious patterns: `password=`, `api_key`, `BEGIN PRIVATE KEY`, tokens).
- **Security AC**: every task tagged `[SEC]` is `done`, and every security acceptance criterion in `spec.md` is covered by a test.
- **Debug leftovers**: no debug mode, verbose error display, or disabled security control (CSRF, TLS verification, auth middleware) left in the diff.

```
Security gate             | Result
--------------------------|----------
Dependency audit          | ✅ 0 high/critical
Secret scan               | ✅ clean
Security AC               | ✅ 2/2 covered
Debug leftovers           | ✅ none
```

### 8. Check for forgotten markers

Search the modified files (relative to the integration branch) for:
- `TODO`, `FIXME`, `XXX`, `HACK` (unless present before the feature)
- `console.log`, `var_dump`, `dump(`, `print_r`, `dd(` (depending on the stack)
- Commented-out code (> 5 consecutive commented lines)

```bash
git diff <integration-branch>..HEAD | grep -E "TODO|FIXME|console\.log|var_dump|dd\("
```

### 9. Check the SDD artifacts

- `spec.md` exists and has `status: approved`
- `plan.md` exists and has `status: approved`
- `tasks.md` exists with all tasks `done`
- `notes.md` may contain free-form notes (no gate)

### 10. Produce the global report

```
═══════════════════════════════════════════════════════════
  Gate Verify — <FEATURE-ID>-<description>
═══════════════════════════════════════════════════════════

Tasks:                    [N/N] done ✅
Git tree:                 clean ✅
Branch:                   <type>/<FEATURE>-... ✅

Tests:
  - Unit:                 ✅ N passed
  - Integration:          ✅ N passed
  - Functional:           ✅ N passed
  - E2E:                  ✅ N passed

Quality gates:
  - <tool 1>:             ✅
  - <tool 2>:             ✅
  - Coverage:             ✅ X% (threshold Y%)

Security gate:
  - Dependency audit:     ✅ 0 high/critical
  - Secret scan:          ✅ clean
  - Security AC:          ✅ covered
  - Debug leftovers:      ✅ none

Forgotten markers:        ✅ none

SDD artifacts:
  - spec.md:              ✅ approved
  - plan.md:              ✅ approved
  - tasks.md:             ✅ N/N tasks done

═══════════════════════════════════════════════════════════
  GLOBAL STATUS: ✅ READY (or ❌ BLOCKED)
═══════════════════════════════════════════════════════════
```

### 11. Record the gate result in `notes.md`

Append to `.claude/sdd/<feature>/notes.md` (this is an SDD artifact, not source code — the read-only rule applies to the project's code):

```markdown
## Verify gate — <date> <time>

- Result: READY (or BLOCKED)
- HEAD: <commit sha>
- Summary: <one line per red point, or "all green">
```

`/sdd-review` uses this entry as proof that the technical gate ran.

### 12. Announce the next step

**If everything is green**:

```
✅ Technical gate passed.

Next step: /sdd-review for the functional gate.
```

**If something is red**:

```
❌ Technical gate not passed.

Blocking points:
- [precise list of the problems]

Action: fix and re-run /sdd-verify.
```

## Stop rules

- **Do NOT run `/sdd-review` automatically**: the functional gate is a distinct step that deserves an explicit trigger
- **Do NOT commit fixes** during `/sdd-verify`: the command is read-only on the code. Fixes go through `/sdd-implement` (a new corrective task) or, as a "last-minute fix", via a manual commit
- **Do NOT bypass a red test** "because it's flaky": report the problem, don't hide it
- **Do NOT push automatically**: pushing is an explicit human action
