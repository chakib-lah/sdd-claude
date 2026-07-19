#!/usr/bin/env bash
# SDD Claude consistency audit — run after any change to the package.
# Usage: bash scripts/audit.sh   (from any directory)
#
# Checks that the framework is installable, consistent, complete and duplication-free:
#   1. Structure       — skills tree + global-agents + installers
#   2. Completeness    — 15 core commands + 5 SDD agents per skill, 8 global agents
#   3. Ghost refs      — every referenced rule/command actually exists
#   4. Delegations     — test-generator / plan-architect consistent
#   5. Docs            — correct command count, skills documented
#   6. Anti-drift      — core masters + shared groups byte-identical (hash)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1   # move to the toolkit root
err=0
say(){ printf '%s\n' "$*"; }
fail(){ printf '  ✗ %s\n' "$*"; err=$((err+1)); }
ok(){ printf '  ✓ %s\n' "$*"; }
hashf(){ md5sum < "$1" | cut -d' ' -f1; }

# ---- Reference lists (the package's sources of truth) ----
SKILLS="sdd-php-backend sdd-php-symfony sdd-symfony-angular sdd-angular-node"
CORE_CMDS="sdd-start sdd-spec sdd-spec-check sdd-plan sdd-tasks sdd-implement sdd-verify sdd-review sdd-mr sdd-archive sdd-status sdd-hotfix sdd-upgrade sdd-changelog retro-spec"
SDD_AGENTS="spec-writer plan-architect task-decomposer test-generator code-reviewer"
GLOBAL_AGENTS="debugger git-assistant security-reviewer refactoring-advisor symfony-expert angular-expert doctrine-migration-expert phpstan-fixer"

# =====================================================================
say "== 1. Structure (skills, global-agents, installers) =="
before=$err
for s in $SKILLS; do
  [ -f "skills/$s/SKILL.md" ] || fail "$s: SKILL.md missing"
  for d in agents commands rules templates; do
    if [ ! -d "skills/$s/reference/$d" ]; then
      fail "$s: reference/$d directory missing"
    elif [ -z "$(ls -A "skills/$s/reference/$d" 2>/dev/null)" ]; then
      fail "$s: reference/$d empty"
    fi
  done
  # option A — no hooks: settings.json must neither exist nor be referenced
  [ -f "skills/$s/reference/settings.json" ] && fail "$s: settings.json present (option A — no hooks)"
  grep -q "settings.json" "skills/$s/SKILL.md" 2>/dev/null && fail "$s: SKILL.md references settings.json (ghost)"
done
[ -d global-agents ] || fail "global-agents/ missing"
for d in core/commands core/agents core/rules core/templates; do
  [ -d "$d" ] || fail "directory $d missing"
done
# installers: every skill must be wired up, and no ghost skill
for s in $SKILLS; do
  grep -q "$s" install.sh  2>/dev/null || fail "install.sh does not reference skill $s"
  grep -q "$s" install.ps1 2>/dev/null || fail "install.ps1 does not reference skill $s"
done
for d in skills/*/; do
  s=$(basename "$d")
  echo "$SKILLS" | grep -qw "$s" || fail "skill not declared in the reference list/installer: $s"
done
[ $err -eq $before ] && ok "tree of the 4 skills + global-agents + installers conforms"

# =====================================================================
say "== 2. Completeness (15 core commands + 5 SDD agents / skill, 8 global agents) =="
before=$err
for c in $CORE_CMDS; do [ -f "core/commands/$c.md" ] || fail "core: missing command: $c"; done
for a in $SDD_AGENTS; do [ -f "core/agents/$a.md" ]   || fail "core: missing SDD agent: $a"; done
for s in $SKILLS; do
  for c in $CORE_CMDS; do [ -f "skills/$s/reference/commands/$c.md" ] || fail "$s: missing core command: $c"; done
  for a in $SDD_AGENTS; do [ -f "skills/$s/reference/agents/$a.md" ]   || fail "$s: missing SDD agent: $a"; done
done
for a in $GLOBAL_AGENTS; do [ -f "global-agents/$a.md" ] || fail "missing global agent: $a"; done
[ $err -eq $before ] && ok "15 core commands + 5 SDD agents present everywhere, 8 global agents present"

# =====================================================================
say "== 3. Ghost references (cited rules / commands actually exist) =="
before=$err
# 3a. historically deleted files that must no longer be cited
for t in sdd-methodology.md 50-team-templates.md; do
  c=$(grep -rl "$t" core skills 2>/dev/null | wc -l)
  [ "$c" -eq 0 ] || fail "remaining ghost reference: $t ($c files)"
done
# 3b. every cited rule `.claude/rules/X.md` exists in core/rules OR in a skill
#     (global existence: avoids false positives on cross-stack examples,
#      e.g. sdd-upgrade.md which lists Layer 2 rules for illustration)
for r in $(grep -rhoE "\.claude/rules/[a-z0-9-]+\.md" core skills 2>/dev/null | sed 's|.*/||' | sort -u); do
  { [ -f "core/rules/$r" ] || find skills -path "*/reference/rules/$r" 2>/dev/null | grep -q .; } \
    || fail "referenced rule not found anywhere: $r"
done
# 3c. every cited command `.claude/commands/X.md` exists in core/commands OR in a skill
for c in $(grep -rhoE "\.claude/commands/[a-z0-9-]+\.md" core skills 2>/dev/null | sed 's|.*/||' | sort -u); do
  { [ -f "core/commands/$c" ] || find skills -path "*/reference/commands/$c" 2>/dev/null | grep -q .; } \
    || fail "referenced command not found anywhere: $c"
done
[ $err -eq $before ] && ok "no ghost references (rules + commands resolved)"

# =====================================================================
say "== 4. Agent delegations (test-generator / plan-architect) =="
before=$err
for s in $SKILLS; do
  grep -m1 '^description:' "skills/$s/reference/agents/plan-architect.md" 2>/dev/null | grep -q '/sdd-plan' \
    || fail "$s: plan-architect does not cite /sdd-plan"
  # test-generator must only cite test commands actually present in THIS skill
  cited=$(grep -m1 '^description:' "skills/$s/reference/agents/test-generator.md" 2>/dev/null | grep -oE '/[a-z]+-test')
  for c in $cited; do
    [ -f "skills/$s/reference/commands/${c#/}.md" ] || fail "$s: test-generator cites $c but the command does not exist"
  done
done
[ $err -eq $before ] && ok "plan-architect cites /sdd-plan; test-generator only cites existing commands"

# =====================================================================
say "== 5. Docs (command count, skills documented, install paths) =="
before=$err
# wrong count: the canonical number is 15
c=$(grep -rlE '\b(9|14) (command|commande)' README.md INSTALL.md skills/README.md skills/*/SKILL.md 2>/dev/null | wc -l)
[ "$c" -eq 0 ] || fail "docs: wrong command count (9/14) in $c file(s)"
# every skill must be documented in the decision tree
for s in $SKILLS; do
  grep -q "$s" skills/README.md 2>/dev/null || fail "skills/README.md does not mention $s"
done
[ $err -eq $before ] && ok "command count correct (15) and 4 skills documented"

# =====================================================================
say "== 6. Content equality of shared files (anti-drift) =="
before=$err
# 6a. The core/ masters must be byte-identical in the 4 skills.
#     Legitimate exclusion: test-generator.md (adapted per stack).
for cf in core/commands/*.md core/agents/*.md core/templates/*.md core/rules/*.md; do
  rel=${cf#core/}                       # e.g. commands/sdd-spec.md
  [ "$rel" = "agents/test-generator.md" ] && continue
  base=$(hashf "$cf")
  for s in $SKILLS; do
    sf="skills/$s/reference/$rel"
    if [ ! -f "$sf" ]; then fail "$s: core master missing: $rel"
    elif [ "$(hashf "$sf")" != "$base" ]; then fail "$s: $rel differs from core/ (drift)"; fi
  done
done
# 6b. Shared files OUTSIDE core that must be identical across the relevant skills.
#     Legitimate exclusions (per-stack divergence): 10-code-conventions, 30-tests-strategy,
#     40-quality-gates, api-contracts, migration-guard.
check_shared(){
  local label="$1"; local skills="$2"; shift 2
  local rel ref refhash s f h
  for rel in "$@"; do
    ref=""; refhash=""
    for s in $skills; do
      f="skills/$s/reference/$rel"
      [ -f "$f" ] || { fail "$label: $rel missing from $s"; continue; }
      h=$(hashf "$f")
      if [ -z "$ref" ]; then ref="$s"; refhash="$h"
      elif [ "$h" != "$refhash" ]; then fail "$label: $rel differs between $ref and $s (drift)"; fi
    done
  done
}
check_shared "angular" "sdd-symfony-angular sdd-angular-node" \
  commands/angular-component.md commands/angular-service.md commands/angular-test.md \
  rules/angular-conventions.md
check_shared "symfony" "sdd-php-symfony sdd-symfony-angular" \
  commands/symfony-entity.md commands/symfony-service.md commands/symfony-controller.md commands/symfony-test.md \
  rules/doctrine-conventions.md
[ $err -eq $before ] && ok "27 core masters + angular/symfony groups identical (hash)"

# =====================================================================
echo ""
if [ $err -eq 0 ]; then echo "✅ AUDIT OK — no inconsistency detected."; else echo "❌ AUDIT: $err problem(s) detected."; fi
exit $err
