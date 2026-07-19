---
description: SDD functional gate — checks AC coverage by the implementation
---

# /sdd-review

**SDD functional gate**: verify that **every acceptance criterion** in `spec.md` is actually covered by the implementation and the tests.

This command is complementary to `/sdd-verify`: Verify checks that the machinery runs, Review checks that the functional promise is kept.

## Blocking prerequisites

- An active SDD feature must exist
- `/sdd-verify` must have **passed** beforehand: look for a `Verify gate` entry with `Result: READY` in `notes.md` whose `HEAD` matches the current commit. If it is missing or stale (commits made since), **refuse** and ask to run `/sdd-verify` first. The user may explicitly override ("review anyway") — record that override in `notes.md`.
- `spec.md` must have `status: approved`
- `tasks.md` must have all its tasks `done`

## Steps

### 1. Detect the active feature

Identify the feature from the Git branch.

### 2. Load the SDD artifacts

Read:
- `.claude/sdd/<feature>/spec.md` (AC reference)
- `.claude/sdd/<feature>/plan.md` (technical design reference)
- `.claude/sdd/<feature>/tasks.md` (AC ↔ tasks ↔ commits mapping)

### 3. Extract the list of acceptance criteria

Parse the "Acceptance criteria" section of `spec.md` and list each AC with an identifier:

```
AC-1: When [situation], the system [action] and [expected result]
AC-2: ...
AC-3: ...
```

### 4. For each AC, verify coverage

For each AC, identify:

#### Coverage by the code

Read the full diff of the feature:

```bash
git diff <integration-branch>..HEAD
```

Identify the files and lines that implement the behavior described by the AC. If the implementation is unclear, flag it.

#### Coverage by the tests

For each AC, identify the test(s) that validate it. The mapping is in `tasks.md` (`ACs covered` field) if filled in, otherwise by reading the modified/added tests.

An AC is considered **covered** if there is at least one test that:
- Sets up the AC's `situation`
- Executes the `action`
- Verifies the `result`

### 5. Check for scope creep

Identify in the diff the changes that **match no AC** and are not in the plan. These changes must be:
- Justified (necessary refactoring, consequence of an AC)
- Listed in the report for discussion

### 6. Check the out-of-scope items

Verify that the items listed under "Out of scope" in `spec.md` are **not** implemented. If one of them is, that is a scope creep signal.

### 7. Check the non-regressions

If the spec contains non-regression ACs (typical for bugfixes), explicitly verify their coverage by tests.

### 8. Check the constitution

If `.claude/rules/05-constitution.md` exists with `status: ratified`, verify that the diff violates none of its principles. A violation of a ratified principle is a **blocking finding** (cite the `PN` and the offending files). Without a ratified constitution, skip with the mention "no constitution".

### 9. Produce the AC-by-AC report

```
═══════════════════════════════════════════════════════════
  Gate Review — <FEATURE-ID>-<description>
═══════════════════════════════════════════════════════════

AC-1: When [situation], the system [action] and [expected result]
  Code           : ✅ Implemented in src/.../FileA.php:42-58
  Tests          : ✅ Covered by tests/.../FileATest.php::testSituation
  Tasks          : T002, T005
  Status         : ✅ COVERED

AC-2: ...
  Code           : ⚠️ Partially implemented (only the nominal case)
  Tests          : ❌ No test found for the error case
  Tasks          : T003
  Status         : ❌ NOT COVERED (error case missing)

AC-3: ...
  ...

═══════════════════════════════════════════════════════════
  Scope creep detected:
  - src/.../FileX.php: change not justified by any AC
═══════════════════════════════════════════════════════════
  Out of scope respected: ✅
═══════════════════════════════════════════════════════════
  Constitution: ✅ respected (or ❌ violates P2 / — no constitution)
═══════════════════════════════════════════════════════════
  Non-regressions:
  - AC-3 (first save): ✅ covered by testFirstSave
═══════════════════════════════════════════════════════════

  GLOBAL STATUS: ✅ READY TO PUSH  (or ❌ BLOCKED)
═══════════════════════════════════════════════════════════
```

### 10. Announce the next step

**If all ACs are covered and there is no scope creep**:

```
✅ Functional gate passed.

You can set the spec.md frontmatter to `status: implemented`,
then push and create the MR.
```

**If one or more ACs are not covered**:

```
❌ Functional gate not passed.

Uncovered ACs: AC-2, AC-5

Recommended action:
1. Add a corrective task to tasks.md (T00N+1)
2. Mark it `pending`
3. Run /sdd-implement to handle it
4. Re-run /sdd-verify then /sdd-review
```

**If scope creep is detected**:

```
⚠️ Scope creep detected:
- [list of out-of-scope changes]

Decision to make:
- Justify it in plan.md or notes.md
- Or remove it from the commit
```

## Stop rules

- **Do not modify the code**: the review is read-only
- **Do not commit fixes**: go through `/sdd-implement` with a new task
- **Do not push**: that is an explicit human action
- **Be strict about partially covered ACs**: an AC that only covers the nominal case without the error cases is NOT covered
- **Report scope creep even if minor**: it is an opportunity for a team discussion

---

## When an AC is not covered — Fix + re-review cycle

### Generate the corrective tasks

For each uncovered AC, add a corrective task at the end of `tasks.md` (without modifying the existing T001+ tasks):

```markdown
- [ ] TC001 [Fix] Cover AC-N: <short description of the missing behavior>
  - **Done when**: the test validating AC-N is green
  - **Files**: [files to modify or add]
  - **Tests**: [suite to run]
  - **ACs covered**: AC-N
  - **Blocked by**: *(none, or T00X if applicable)*
  - **Commit SHA**: *(filled in after /sdd-implement)*
```

Prefix them with `TC` (Corrective Task) to distinguish them from the initial implementation tasks.

### Announce the corrective cycle

```
❌ Functional gate not passed.

Uncovered ACs:
- AC-3: When the user submits without an email, the form displays an error
- AC-5: When the token is expired, the route returns 401

Corrective tasks generated in tasks.md:
  TC001: Cover AC-3 — frontend email validation
  TC002: Cover AC-5 — token expiration check in middleware

Procedure:
1. Implement TC001, then TC002 via /sdd-implement
2. Re-run /sdd-verify to check the tests
3. Re-run /sdd-review for the functional gate
```

### Re-review rule

`/sdd-review` can be run as many times as needed until all ACs are covered. Each run re-reads the entire spec and diff.
