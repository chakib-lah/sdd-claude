---
description: Extract a clean class from procedural or God-class legacy code, with progressive migration path
---

# /extract-class

**Refactoring command (brownfield only)**: extract a clean class from procedural code or a legacy God class.

This command produces **a spec and a plan**, not the code directly. The code is then implemented via `/sdd-implement` after the spec is validated.

## Blocking prerequisites

- Brownfield mode
- Identified legacy source code (file or directory)
- Rules available: `refactoring-guard.md`, `legacy-rules.md`

## Usage

```
/extract-class <path/to/legacy-file.php> [<target-class-name>]
```

Examples:
- `/extract-class src/Legacy/user_functions.php UserService`
- `/extract-class src/Legacy/OldOrderManager.php`

## Steps

### 1. Read the legacy code

Read the provided file or directory in full. Identify:
- All functions or methods
- All global variables used
- All `require`/`include` (incoming and outgoing)
- All direct accesses to `$_GET`, `$_POST`, `$_SESSION`, `$GLOBALS`
- All `echo`, `print`, `die`, `exit`
- All calls to `mysqli_*`, `pdo`, etc.

### 2. Identify responsibilities

Group the code by **business responsibility**:
- Validation
- Persistence (DB access)
- Business logic
- Presentation (HTML, JSON rendering)
- External communication (emails, APIs)
- Logging

One class = one responsibility. If a function touches several responsibilities, it will be decomposed.

### 3. Propose a class breakdown

Display a breakdown plan in the chat:

```
Legacy code analyzed: src/Legacy/user_functions.php (485 lines, 23 functions)

Proposed breakdown:

┌────────────────────────────────────────────────────────────────┐
│ Class: UserRepository                                          │
│ Responsibility: User persistence                               │
│ Legacy functions absorbed:                                     │
│   - get_user_by_id($id)             → find(int $id)           │
│   - get_user_by_email($email)       → findByEmail(string)     │
│   - save_user($data)                → save(User)              │
│   - delete_user($id)                → delete(int)             │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Class: UserValidator                                           │
│ Responsibility: User data validation                           │
│ Legacy functions absorbed:                                     │
│   - validate_email($email)          → validateEmail(string)   │
│   - validate_password($pwd)         → validatePassword(string)│
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Class: UserService                                             │
│ Responsibility: User business logic                            │
│ Legacy functions absorbed:                                     │
│   - register_user($data)            → register(...)           │
│   - login_user($email, $pwd)        → login(...)              │
│   - logout_user()                   → logout()                │
│   - reset_password($email)          → resetPassword(string)   │
└────────────────────────────────────────────────────────────────┘

Global variables detected:
- $db (used by 8 functions) → inject PDO via constructor
- $config (used by 3 functions) → inject Config via constructor
- $_SESSION (used by 5 functions) → dedicated SessionManager

Side effects detected:
- echo in validate_email() → convert to an exception
- die() in save_user() on error → exception
- direct mail() in register_user() → inject MailerInterface
```

### 4. Ask for validation of the breakdown

The user can:
- Accept the breakdown as-is
- Request adjustments (merge two classes, split one, rename)
- Refuse and request another analysis

### 5. Create one SDD feature per extracted class

For each class to extract, create a SDD feature:

```
.claude/sdd/EXTRACT-001-user-repository/
├── spec.md
├── plan.md
├── tasks.md
└── notes.md
```

`EXTRACT-001` is an internal identifier (can be replaced by a Jira ticket `TICK-1234` if relevant).

### 6. Fill in each feature's spec.md

For each class, generate a spec with:

#### Context
- Legacy source code: path and lines concerned
- Why extract: debt, readability, testability

#### Acceptance criteria
- **Non-regression** AC: "When the old code calls `get_user_by_id($id)`, the behavior remains identical" (the most important case)
- **Modern interface** AC: "When the new code calls `$repository->find(int $id)`, it returns `?User`"

#### Design
- Full signature of the new class
- Intermediate adapter if needed (for compatibility bridges)
- Side effects to neutralize

#### Progressive migration plan
- Step 1: create the new class
- Step 2: create an adapter that calls the old legacy code
- Step 3: test the adapter against existing usages
- Step 4: switch callers over to the new class (one by one)
- Step 5: remove the old legacy code once 100% migrated

### 7. Update `legacy-debt.md`

Add to `docs/legacy-debt.md` (create the file if missing):

```markdown
## Modules being extracted

| Legacy module | Target classes | Tickets | Status |
|---|---|---|---|
| user_functions.php | UserRepository, UserValidator, UserService | EXTRACT-001 to EXTRACT-003 | In progress |
```

### 8. Announce

```
✅ Extraction planned: src/Legacy/user_functions.php

3 SDD features created:
- EXTRACT-001-user-repository (.claude/sdd/EXTRACT-001-user-repository/)
- EXTRACT-002-user-validator (.claude/sdd/EXTRACT-002-user-validator/)
- EXTRACT-003-user-service (.claude/sdd/EXTRACT-003-user-service/)

Debt tracked: docs/legacy-debt.md

Next steps:
1. Re-read and validate each spec.md (move to status: approved)
2. /sdd-plan on each feature
3. /sdd-tasks then /sdd-implement
4. Progressive migration — no big bang
```

## Stop rules

- **Do not modify the source code during this command**: this is a planning exercise
- **Do not propose rewriting everything at once**: always a progressive strategy (Strangler Fig)
- **Always include non-regression AC** in the generated specs
- **Always create an intermediate adapter** if legacy code remains a caller
- **Do not forget the side effects**: echo, die, mail, sessions
- **Do not mix several responsibilities** in a single extracted class
- If the legacy code is too tangled to be split cleanly, **say so** and propose a preliminary reorganization step
