# Skeleton — Create a new `sdd-<stack>` stack skill

> Step-by-step guide to add a stack to the SDD Claude following the **current model**: a standalone skill (`SKILL.md` + `reference/`) installed via `install.sh` / `install.ps1`.
> A skill brings together **Layer 1** (the 27 masters copied from `core/`) **and** **Layer 2** (the stack-specific conventions and commands). Layer 3 (business) is added by the team as the project evolves, never here.

Replace `<stack>` with the stack's name (e.g. `python-fastapi`, `java-spring`).

---

## Step 1 — Create the skill's directory tree

```bash
mkdir -p skills/sdd-<stack>/reference/{agents,commands,rules,templates}
```

Expected result:

```
skills/sdd-<stack>/
├── SKILL.md
└── reference/
    ├── agents/
    ├── commands/
    ├── rules/
    └── templates/
```

---

## Step 2 — Copy the 27 masters from `core/` (verbatim)

Layer 1 must be **byte-identical** to `core/` — this is what `scripts/audit.sh` (section 6) verifies. We copy, we never rewrite by hand.

```bash
S=skills/sdd-<stack>/reference
cp core/commands/*.md   "$S/commands/"
cp core/agents/*.md     "$S/agents/"
cp core/templates/*.md  "$S/templates/"
cp core/rules/00-sdd-framework.md   "$S/rules/"
cp core/rules/20-git-conventions.md "$S/rules/"
cp core/rules/50-security.md        "$S/rules/"
```

This installs: the **15 SDD commands**, the **5 agents** (including `test-generator`, which we will adapt in step 4), the **5 templates** and the **3 universal rules**.

> Never modify these files in the skill. The source is `core/`; any divergence is detected by the audit.

---

## Step 3 — Write Layer 2 (stack conventions)

Create the 3 stack rules in `reference/rules/`. They are **read by `/sdd-implement` and `/sdd-verify`**; the universal commands do not know the project's tools and rely on these files.

### `rules/10-code-conventions.md`
- Naming conventions (classes, functions, variables)
- File structure, architectural patterns to follow
- Stack-specific best practices, with ✅ / ❌ examples
- **Must NOT contain**: methodology rules (Layer 1), Git rules (Layer 1), business rules (Layer 3)

### `rules/30-tests-strategy.md`
- Test types (unit, integration, E2E) and tools
- **Exact execution commands** (read by `/sdd-implement` and `/sdd-verify`)
- Test naming conventions, fixtures/mocks strategy, target coverage

### `rules/40-quality-gates.md`
- Quality tools (linter, formatter, static analysis) and **exact commands**
- Required levels, possible pre-commit hooks, policy on warnings

---

## Step 4 — Adapt `agents/test-generator.md` to the stack

`test-generator.md` is the **only agent adapted per skill** (excluded from the hash check). Edit its `description` so that it:
- cites **only the test commands actually present** in this skill (e.g. `/<stack>-test`);
- mentions `/sdd-implement` (automatic activation on a `[Tests]` category task);
- names the stack's real test frameworks.

The 4 other agents (`spec-writer`, `plan-architect`, `task-decomposer`, `code-reviewer`) remain **unchanged** (masters).

> Auto-delegation reminder: commands never hardcode an agent's name. It is the agent that declares, in its `description`, the command that activates it.

---

## Step 5 — Write the `<stack>-*` scaffolding commands

Optional but recommended: auxiliary commands (e.g. `<stack>-entity`, `<stack>-test`) in `reference/commands/`. Same format as the SDD commands:
- frontmatter with `description`
- prerequisites, steps, stop rules
- **read `spec.md` / `plan.md`** to draw from their content (never "blindly")
- **do not replace `/sdd-implement`**: they are scaffolding tools, not SDD phases

---

## Step 6 — Write `SKILL.md`

At the skill's root. It describes when the skill activates (detected stack) and what it deploys. Take inspiration from an existing `SKILL.md` (`skills/sdd-php-symfony/SKILL.md`, etc.). It lists the deployment: 15 commands + 5 agents + rules + templates.

---

## Step 7 — Wire up the skill

- **`install.sh`**: add `sdd-<stack>` to the `SKILLS` variable.
- **`install.ps1`**: add `sdd-<stack>` to the skills array.
- **`skills/README.md`**: add the row in the decision tree + the skills table.

---

## Step 8 — Validate

```bash
bash scripts/audit.sh
```

Must display `✅ AUDIT OK`. The audit checks in particular:
- the skill's structure (`SKILL.md` + `reference/{agents,commands,rules,templates}`);
- completeness (15 commands + 5 agents);
- the wiring in the installers;
- the hash equality of the 27 masters with `core/`.

---

## Forbidden divergences

- ❌ Do not rename the universal SDD commands (`/sdd-start`, etc.).
- ❌ Do not modify the Layer 1 masters in the skill (`00-sdd-framework.md`, `20-git-conventions.md`, `50-security.md`, `sdd-*.md`, `retro-spec.md`, templates) — the source is `core/`.
- ❌ Do not mix methodology and technology (no tool name in `00-sdd-framework.md`).
- ❌ Do not create business skills here (Layer 3, not Layer 2).
- ❌ Do not change the task naming convention (`T001, T002…`).

---

## Customization (stays in Layer 2)

A skill can be adjusted for a project type: quality gate levels, specific security rules, additional scaffolding commands. These adjustments remain in **Layer 2**; Layer 1 (the 27 masters) stays untouched.
