# Installation — SDD Claude

> One package. One command. Everything included.

> ⚠️ **Warning** — installing these skills and agents replaces any previously installed skill or agent with the same name in `~/.claude/skills/` and `~/.claude/agents/`.

---

## What this package contains

```
sdd-claude/
├── core/                   ← Universal reference (Layer 1)
│   ├── agents/             ← 5 SDD agents (spec-writer, plan-architect...)
│   ├── commands/           ← 17 universal SDD commands
│   ├── rules/              ← Methodology + Git + security + code quality
│   ├── templates/          ← spec/plan/tasks/notes + AMOA exports (jira-story, spec-doc)
│   ├── upgrade/            ← canonical /sdd-upgrade procedure (read at run time, never deployed)
├── skills/                 ← 6 installable skills (Layer 2)
│   ├── sdd-php-backend/
│   │   ├── SKILL.md
│   │   └── reference/
│   │       ├── agents/     ← 5 SDD agents built into the skill
│   │       ├── commands/
│   │       ├── rules/
│   │       └── templates/
│   ├── sdd-php-symfony/    ← same structure
│   ├── sdd-symfony-angular/ ← same structure
│   ├── sdd-angular-node/   ← same structure
│   ├── sdd-java-backend/   ← same structure
│   └── sdd-java-angular/   ← same structure
├── global-commands/        ← global /sdd-upgrade bootstrap → ~/.claude/commands/
├── global-agents/          ← 9 global agents → ~/.claude/agents/
│   ├── debugger.md
│   ├── git-assistant.md
│   ├── security-reviewer.md
│   ├── refactoring-advisor.md
│   ├── symfony-expert.md
│   ├── angular-expert.md
│   ├── doctrine-migration-expert.md
│   ├── phpstan-fixer.md
│   └── spring-java-expert.md
├── scripts/
│   └── audit.sh            ← consistency guardrail
├── install.sh             ← Linux / macOS / WSL2 installer
├── install.ps1            ← Windows installer
├── upgrade-global.sh      ← global ~/.claude updater (Linux / macOS / WSL2)
├── upgrade-global.ps1     ← global ~/.claude updater (Windows)
├── VERSION                ← 1.18.0
└── CHANGELOG.md
```

---

## Installation — quick method (recommended)

### Linux / macOS / WSL2

```bash
unzip sdd-claude.zip -d ~/tools/
cd ~/tools/sdd-claude
bash install.sh
```

The installer links the 6 skills via symlink (auto-updated on every `git pull`), copies the 9 global agents, and installs the global `/sdd-upgrade` bootstrap into `~/.claude/commands/`; re-running is safe — symlinks and byte-identical files are refreshed silently. A real directory found at a skill path is backed up to `<name>.bak-<timestamp>` (never deleted), and a customized global agent is kept and reported (`--force` / `-Force` to overwrite).

### Windows (PowerShell)

```powershell
Expand-Archive sdd-claude.zip -DestinationPath "$env:USERPROFILE\tools\"
cd "$env:USERPROFILE\tools\sdd-claude"
.\install.ps1
```

---

## Installation — manual method (Linux / macOS)

```bash
# 1. Extract the package
unzip sdd-claude.zip -d ~/tools/

# 2. Link the skills (symlink = auto-update on every git pull)
mkdir -p ~/.claude/skills
ln -s ~/tools/sdd-claude/skills/sdd-php-backend     ~/.claude/skills/
ln -s ~/tools/sdd-claude/skills/sdd-php-symfony     ~/.claude/skills/
ln -s ~/tools/sdd-claude/skills/sdd-symfony-angular ~/.claude/skills/
ln -s ~/tools/sdd-claude/skills/sdd-angular-node    ~/.claude/skills/
ln -s ~/tools/sdd-claude/skills/sdd-java-backend    ~/.claude/skills/
ln -s ~/tools/sdd-claude/skills/sdd-java-angular    ~/.claude/skills/

# 3. Copy the global agents
mkdir -p ~/.claude/agents
cp ~/tools/sdd-claude/global-agents/*.md ~/.claude/agents/

# 4. Install the global /sdd-upgrade bootstrap
mkdir -p ~/.claude/commands
cp ~/tools/sdd-claude/global-commands/sdd-upgrade.md ~/.claude/commands/
```

---

## Installation — Windows (PowerShell)

```powershell
# 1. Extract
Expand-Archive sdd-claude.zip -DestinationPath "$env:USERPROFILE\tools\"

# 2. Copy the skills
$skillsDir = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force -Path $skillsDir
$skills = @("sdd-php-backend","sdd-php-symfony","sdd-symfony-angular","sdd-angular-node","sdd-java-backend","sdd-java-angular")
foreach ($s in $skills) {
  Copy-Item -Recurse "$env:USERPROFILE\tools\sdd-claude\skills\$s" $skillsDir
}

# 3. Copy the global agents
$agentsDir = "$env:USERPROFILE\.claude\agents"
New-Item -ItemType Directory -Force -Path $agentsDir
Copy-Item "$env:USERPROFILE\tools\sdd-claude\global-agents\*.md" $agentsDir

# 4. Install the global /sdd-upgrade bootstrap
$commandsDir = "$env:USERPROFILE\.claude\commands"
New-Item -ItemType Directory -Force -Path $commandsDir
Copy-Item "$env:USERPROFILE\tools\sdd-claude\global-commands\sdd-upgrade.md" $commandsDir
```

---

## Verify the installation

```bash
# Available skills
ls ~/.claude/skills/
# sdd-php-backend  sdd-php-symfony  sdd-symfony-angular  sdd-angular-node  sdd-java-backend  sdd-java-angular

# Available global agents
ls ~/.claude/agents/
# debugger.md  git-assistant.md  symfony-expert.md  ...
```

---

## Activate on a project

```bash
cd ~/projects/my-project
claude
```

In Claude Code:

```
Generate the SDD framework for this project.
```

Claude detects the stack, activates the right skill, and deploys in one pass:
- 17 SDD commands into `.claude/commands/`
- Stack rules into `.claude/rules/`
- **5 SDD agents into `.claude/agents/`** ← included automatically
- Templates into `.claude/sdd/_template/`

```bash
git add .claude/
git commit -m "chore: install SDD framework"
```

Everyone on the team who clones the repo gets commands + agents + rules in one go.

---

## Updating sdd-claude

```bash
# If you used symlinks (recommended method)
cd ~/tools/sdd-claude
git pull
# The 6 skills are automatically up to date

# Update the global ~/.claude (skill symlinks + global agents)
./upgrade-global.sh          # Windows: .\upgrade-global.ps1
```

`upgrade-global.sh` applies two distinct policies. **Skills**: links are repaired/added silently (a link is not user data); a **real directory** found at a skill path is backed up to `<name>.bak-<timestamp>`, never deleted. **Global agents**: **stale but unmodified** copies are updated; a customized or translated copy is never silently overwritten — it is reported and you are asked (`--force` / `--keep-custom` to skip the prompt). Your own agents in `~/.claude/agents/` are never touched.

Projects are updated separately: run `/sdd-upgrade` inside each project.

---

## Guardrail: check the package's consistency

After any change to the toolkit (adding a command, an agent, a rule…), run:

```bash
cd ~/tools/sdd-claude
bash scripts/audit.sh
```

The script checks, in six sections: the skills' structure and installer wiring, completeness (17 commands + 5 agents per skill, 9 global agents), absence of ghost references (rules, and `settings.json` which is no longer deployed), correct agent delegations, docs and release consistency (version, CHANGELOG, tag; anatomies, command write-steps and agent skeletons in sync with the templates; Layer 1 free of forbidden technology names; extension-guide command list complete), and anti-drift by hash of the shared files. Output is `✅ AUDIT OK` or the list of problems.
