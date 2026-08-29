# Project SDD features

> Guide to the `.claude/sdd/` directory — home of the project's Spec-Driven Development artifacts.

## How this directory works

- Each feature lives in its own folder: `.claude/sdd/<FEATURE-ID>-<description>/` (`spec.md`, `plan.md`, `tasks.md`, `notes.md`, and `exports/` for retrospective deliverables).
- **Live feature state is never stored in this file.** Statuses, task ratios and the active feature are derived from the feature folders and their frontmatter — run `/sdd-status` for the current dashboard.
- Merged features are moved into [`_archive/`](./_archive/) by `/sdd-archive`; the folder itself is the archive record.
- Templates used by the commands live in `_template/`.

## How to start a feature

```
/sdd-start <FEATURE-ID>-<description>
```

Full workflow: see `.claude/rules/00-sdd-framework.md`.

For Git conventions: see `.claude/rules/02-git-conventions.md`.

For stack-specific code conventions: see `.claude/rules/10-code-conventions.md` (added by the stack skill).
