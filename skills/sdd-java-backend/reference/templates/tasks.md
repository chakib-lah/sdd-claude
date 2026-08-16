---
feature: <kebab-case-name>
status: draft
created: <YYYY-MM-DD>
author: <name>
---

# Tasks: <Feature title>

## Reminder

- One task = 30 min to 2 h max
- One task = a single **local** commit · one **implementation phase** = one commit on the branch (squashed by `/sdd-implement`)
- Implementation phases are not the 4 SDD phases (Specify/Plan/Tasks/Implement): they group tasks into revertable milestones
- A small feature = a single phase; each phase must leave the codebase consistent (green tests)
- Markers: `[ ]` pending · `[~]` in progress · `[x]` done — no other marker is valid
- `[P]` = parallelizable (no dependency with the other `[P]` tasks) — a `[P]` group never straddles two phases
- `Blocked by` = this task cannot start before the blocking one is `done`
- The commit SHAs (task and phase) are filled in automatically by `/sdd-implement`

---

## Tasks

### Phase 1: <Milestone name>

- **Goal**: one line — the coherent, revertable state this phase leaves the codebase in
- **Phase commit SHA**: *(filled in by /sdd-implement after the phase squash)*

- [ ] T001 [Category] Short description of the task
  - **Done when**: testable and binary completion criterion
  - **Files**: precise list of files touched
  - **Tests**: test suite(s) to run
  - **ACs covered**: AC-1, AC-2
  - **Blocked by**: *(none)*
  - **Commit SHA**:

### Phase 2: <Milestone name>

- **Goal**: one line — the coherent, revertable state this phase leaves the codebase in
- **Phase commit SHA**: *(filled in by /sdd-implement after the phase squash)*

- [ ] T002 [Category] Short description [P]
  - **Done when**: completion criterion
  - **Files**: files touched
  - **Tests**: test suite(s)
  - **ACs covered**: AC-3
  - **Blocked by**: T001
  - **Commit SHA**:

- [ ] T003 [Category] Short description [P]
  - **Done when**: completion criterion
  - **Files**: files touched
  - **Tests**: test suite(s)
  - **ACs covered**: AC-4
  - **Blocked by**: T001
  - **Commit SHA**:
