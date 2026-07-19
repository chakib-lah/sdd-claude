---
feature: <kebab-case-name>
status: draft
created: <YYYY-MM-DD>
author: <name>
---

# Tasks: <Feature title>

## Reminder

- One task = 30 min to 2 h max
- One task = a single commit
- Markers: `[ ]` pending · `[~]` in progress · `[x]` done — no other marker is valid
- `[P]` = parallelizable (no dependency with the other `[P]` tasks)
- `Blocked by` = this task cannot start before the blocking one is `done`
- The commit SHA is filled in automatically by `/sdd-implement`

---

## Tasks

- [ ] T001 [Category] Short description of the task
  - **Done when**: testable and binary completion criterion
  - **Files**: precise list of files touched
  - **Tests**: test suite(s) to run
  - **Covered ACs**: AC-1, AC-2
  - **Blocked by**: *(none)*
  - **Commit SHA**:

- [ ] T002 [Category] Short description [P]
  - **Done when**: completion criterion
  - **Files**: files touched
  - **Tests**: test suite(s)
  - **Covered ACs**: AC-3
  - **Blocked by**: T001
  - **Commit SHA**:

- [ ] T003 [Category] Short description [P]
  - **Done when**: completion criterion
  - **Files**: files touched
  - **Tests**: test suite(s)
  - **Covered ACs**: AC-4
  - **Blocked by**: T001
  - **Commit SHA**:
