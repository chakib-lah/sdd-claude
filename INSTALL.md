# Installation — SDD Claude

> One package. One command. Everything included.

> ⚠️ **Warning** — sdd-claude uses the same skill and agent names as sdd-toolkit. Installing it therefore replaces any previously installed sdd-toolkit skills/agents: the two should not be installed simultaneously.

---

## What this package contains

```
sdd-claude/
├── core/                   ← Universal reference (Layer 1)
│   ├── agents/             ← 5 SDD agents (spec-writer, plan-architect...)
│   ├── commands/           ← 17 universal SDD commands
│   ├── rules/              ← Methodology + Git
│   ├── templates/          ← spec/plan/tasks/notes
│   └── ci-templates/       ← GitLab CI snippets
├── skills/                 ← 4 installable skills (Layer 2)
│   ├── sdd-php-backend/
│   │   ├── SKILL.md
│   │   └── reference/
│   │       ├── agents/     ← 5 SDD agents built into the skill
│   │       ├── commands/
│   │       ├── rules/
│   │       └── templates/
│   ├── sdd-php-symfony/    ← same structure
│   ├── sdd-symfony-angular/ ← same structure
│   └── sdd-angular-node/   ← same structure
├── global-agents/          ← 8 global agents → ~/.claude/agents/
│   ├── debugger.md
│   ├── git-assistant.md
│   ├── security-reviewer.md
│   ├── refactoring-advisor.md
│   ├── symfony-expert.md
│   ├── angular-expert.md
│   ├── doctrine-migration-expert.md
│   └── phpstan-fixer.md
├── scripts/
│   └── audit.sh            ← consistency guardrail
├── install.sh             ← Linux / macOS / WSL2 installer
├── install.ps1            ← Windows installer
├── VERSION                ← 1.1.0
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

The installer links the 4 skills via symlink (auto-updated on every `git pull`) and copies the 8 global agents. Idempotent: safe to re-run.

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

# 3. Copy the global agents
mkdir -p ~/.claude/agents
cp ~/tools/sdd-claude/global-agents/*.md ~/.claude/agents/
```

---

## Installation — Windows (PowerShell)

```powershell
# 1. Extract
Expand-Archive sdd-claude.zip -DestinationPath "$env:USERPROFILE\tools\"

# 2. Copy the skills
$skillsDir = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force -Path $skillsDir
$skills = @("sdd-php-backend","sdd-php-symfony","sdd-symfony-angular","sdd-angular-node")
foreach ($s in $skills) {
  Copy-Item -Recurse "$env:USERPROFILE\tools\sdd-claude\skills\$s" $skillsDir
}

# 3. Copy the global agents
$agentsDir = "$env:USERPROFILE\.claude\agents"
New-Item -ItemType Directory -Force -Path $agentsDir
Copy-Item "$env:USERPROFILE\tools\sdd-claude\global-agents\*.md" $agentsDir
```

---

## Verify the installation

```bash
# Available skills
ls ~/.claude/skills/
# sdd-php-backend  sdd-php-symfony  sdd-symfony-angular  sdd-angular-node

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

## Updating

```bash
# If you used symlinks (recommended method)
cd ~/tools/sdd-claude
git pull
# The 4 skills are automatically up to date

# Update the global agents
cp ~/tools/sdd-claude/global-agents/*.md ~/.claude/agents/
```

---

## Difference with previous packages (former sdd-toolkit V1/V2)

| | V1 | V2 | sdd-claude 1.1 |
|---|---|---|---|
| ZIPs to install | 1 | 2 (toolkit + agents) | **1** |
| Agents included in the skill | ❌ | ❌ | **✅** |
| Universal commands | 9 | 14 | **17** |
| Available skills | 3 | 4 | **4** |
| Global agents | ❌ | Separate | **Included** |

```bash
git pull
# The symlinks follow automatically, nothing else to do.

# On Windows (copy, not symlink): re-run the installer after the pull
# .\install.ps1
```

---

## Guardrail: check the package's consistency

After any change to the toolkit (adding a command, an agent, a rule…), run:

```bash
cd ~/tools/sdd-claude
bash scripts/audit.sh
```

The script checks: absence of ghost references (rules, and `settings.json` which is no longer deployed), correct agent delegations, 17 commands per skill, docs consistency. Output is `✅ AUDIT OK` or the list of problems.
