#!/usr/bin/env bash
# SDD Claude consistency audit — run after any change to the package.
# Usage: bash scripts/audit.sh   (from any directory)
#
# Checks that the framework is installable, consistent, complete and duplication-free:
#   1. Structure       — skills tree + global-agents + installers
#   2. Completeness    — 17 core commands + 5 SDD agents per skill, 9 global agents
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
# ---- Portable hash tool (resolved ONCE at startup) ----
# The anti-drift check (section 6) is only as trustworthy as this function:
# a missing tool must be a HARD failure, never a silent empty string
# (md5sum absent on stock macOS → empty hashes → every file compares equal).
# Reading from stdin (< "$1") keeps filenames out of the hash output.
if command -v md5sum >/dev/null 2>&1; then
  HASH_TOOL='md5sum'
  hashf(){ md5sum < "$1" | cut -d' ' -f1; }
elif command -v md5 >/dev/null 2>&1; then
  HASH_TOOL='md5 (BSD)'
  hashf(){ md5 < "$1" | awk '{print $NF}'; }
elif command -v openssl >/dev/null 2>&1; then
  HASH_TOOL='openssl md5'
  hashf(){ openssl md5 -r < "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  HASH_TOOL='shasum -a 256'
  hashf(){ shasum -a 256 < "$1" | cut -d' ' -f1; }
else
  printf 'FATAL: no hash tool available (need one of: md5sum, md5, openssl, shasum).\n' >&2
  printf 'The anti-drift check (section 6) cannot run without one — aborting.\n' >&2
  exit 1
fi
say "hash tool: $HASH_TOOL"

# ---- Reference lists (the package's sources of truth) ----
SKILLS="sdd-php-backend sdd-php-symfony sdd-symfony-angular sdd-angular-node sdd-java-backend sdd-java-angular"
CORE_CMDS="sdd-start sdd-spec sdd-clarify sdd-spec-check sdd-plan sdd-tasks sdd-implement sdd-verify sdd-review sdd-mr sdd-archive sdd-status sdd-hotfix sdd-upgrade sdd-changelog sdd-revert retro-spec"
SDD_AGENTS="spec-writer plan-architect task-decomposer test-generator code-reviewer"
GLOBAL_AGENTS="debugger git-assistant security-reviewer refactoring-advisor symfony-expert angular-expert doctrine-migration-expert phpstan-fixer spring-java-expert"

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
  # every deployable template must be listed in SKILL.md (sdd-readme.md deploys as sdd/README.md)
  for f in "skills/$s/reference/templates/"*.md; do
    [ -e "$f" ] || continue
    t=$(basename "$f")
    [ "$t" = "sdd-readme.md" ] && continue
    grep -qF "_template/$t" "skills/$s/SKILL.md" 2>/dev/null || fail "$s: SKILL.md does not deploy _template/$t"
  done
  # reverse: every _template/<f> cited in SKILL.md must exist in reference/templates/ (ghost)
  for t in $(grep -hoE '_template/[a-z0-9-]+\.md' "skills/$s/SKILL.md" 2>/dev/null | sed 's|_template/||' | sort -u); do
    [ -f "skills/$s/reference/templates/$t" ] || fail "$s: SKILL.md deploys ghost template _template/$t"
  done
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
# global updaters present (they auto-discover skills, no per-skill wiring needed)
[ -x upgrade-global.sh ]  || fail "upgrade-global.sh missing or not executable"
[ -f upgrade-global.ps1 ] || fail "upgrade-global.ps1 missing"
# agent frontmatter: tools must use bracketed capitalized names — lowercase
# ("tools: read, bash") is not recognized by Claude Code and the agent refuses to spawn
for f in core/agents/*.md global-agents/*.md skills/*/reference/agents/*.md; do
  [ -f "$f" ] || continue
  t=$(grep -m1 '^tools:' "$f" 2>/dev/null)
  [ -z "$t" ] && continue
  printf '%s\n' "$t" | grep -qE '^tools: \[[A-Z][A-Za-z]*(, [A-Z][A-Za-z]*)*\]$' \
    || fail "invalid tools frontmatter (expected e.g. 'tools: [Read, Bash]'): $f"
done
for d in skills/*/; do
  s=$(basename "$d")
  echo "$SKILLS" | grep -qw "$s" || fail "skill not declared in the reference list/installer: $s"
done
[ $err -eq $before ] && ok "tree of the 6 skills + global-agents + installers conforms"

# =====================================================================
say "== 2. Completeness (17 core commands + 5 SDD agents / skill, 9 global agents) =="
before=$err
for c in $CORE_CMDS; do [ -f "core/commands/$c.md" ] || fail "core: missing command: $c"; done
for a in $SDD_AGENTS; do [ -f "core/agents/$a.md" ]   || fail "core: missing SDD agent: $a"; done
for s in $SKILLS; do
  for c in $CORE_CMDS; do [ -f "skills/$s/reference/commands/$c.md" ] || fail "$s: missing core command: $c"; done
  for a in $SDD_AGENTS; do [ -f "skills/$s/reference/agents/$a.md" ]   || fail "$s: missing SDD agent: $a"; done
done
for a in $GLOBAL_AGENTS; do [ -f "global-agents/$a.md" ] || fail "missing global agent: $a"; done
[ $err -eq $before ] && ok "17 core commands + 5 SDD agents present everywhere, 9 global agents present"

# =====================================================================
say "== 3. Ghost references (cited rules / commands actually exist) =="
before=$err
# 3a. historically deleted files that must no longer be cited
for t in sdd-methodology.md 50-team-templates.md; do
  c=$(grep -rl "$t" core skills 2>/dev/null | wc -l)
  [ "$c" -eq 0 ] || fail "remaining ghost reference: $t ($c files)"
done
# 3a-ter. rules renamed in v1.3.0: old names may appear ONLY in sdd-upgrade.md
#         (its migration map documents them); anywhere else is drift
for t in 05-constitution.md 20-git-conventions.md 50-security.md 30-tests-strategy.md 40-quality-gates.md; do
  c=$(grep -rlF -- "$t" core skills 2>/dev/null | grep -v '/sdd-upgrade\.md$' | wc -l)
  [ "$c" -eq 0 ] || fail "renamed rule still cited under its old name: $t ($c files)"
done
# 3a-bis. blanked references: list items with EMPTY inline code (e.g. "- `` if present")
#         — residue of a deleted file whose path was blanked instead of the line removed
while IFS= read -r hit; do
  fail "blanked (empty-backtick) reference: $hit"
done < <(grep -rnE '^[[:space:]]*-[[:space:]]*``([^`]|$)' core skills --include='*.md' 2>/dev/null)
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
# wrong count: the canonical number is 17
# ((^|[^0-9]) instead of \b: word boundaries are a GNU extension, inert under BSD grep)
c=$(grep -rlE '(^|[^0-9])(9|12|14|15) (command|commande)' README.md INSTALL.md skills/README.md skills/*/SKILL.md 2>/dev/null | wc -l)
[ "$c" -eq 0 ] || fail "docs: wrong command count (9/12/14/15) in $c file(s)"
# wrong count inside command/agent/rule BODIES too (not just top-level docs)
while IFS= read -r hit; do
  fail "wrong command count in body: $hit"
done < <(grep -rnE '(^|[^0-9])(9|12|14|15) (universal )?(command|commande)' core skills --include='*.md' 2>/dev/null)
# stale version narrative: commands must stay version-agnostic
while IFS= read -r hit; do
  fail "stale version narrative: $hit"
done < <(grep -rnE 'new command v[0-9]' core skills --include='*.md' 2>/dev/null)
# every skill must be documented in the decision tree
for s in $SKILLS; do
  grep -q "$s" skills/README.md 2>/dev/null || fail "skills/README.md does not mention $s"
done
# version coherence: docs must cite the current VERSION
v=$(cat VERSION 2>/dev/null)
for f in README.md INSTALL.md; do
  grep -qF "$v" "$f" 2>/dev/null || fail "docs: $f does not cite current version $v (stale)"
done
# release coherence: VERSION must have a CHANGELOG heading (## [X.Y.Z]).
# "At least one" match — duplicated headings are tolerated (legitimate in forks).
ve=$(printf '%s' "$v" | sed 's/\./\\./g')
grep -qE "^## \[$ve\]" CHANGELOG.md 2>/dev/null \
  || fail "CHANGELOG.md has no '## [$v]' entry for current VERSION"
# release tag: NON-FATAL notice — the toolkit is legitimately consumed as a ZIP
# download or a shallow clone, where tags/history are absent
if git rev-parse --git-dir >/dev/null 2>&1; then
  git tag --list "v$v" 2>/dev/null | grep -qx "v$v" \
    || say "  · notice: git tag v$v not found (create it when releasing)"
else
  say "  · notice: no git history — release tag check skipped"
fi
[ $err -eq $before ] && ok "command count correct (17) and 6 skills documented"

# =====================================================================
say "== 6. Content equality of shared files (anti-drift) =="
before=$err
# 6a. The core/ masters must be byte-identical in the 6 skills.
#     Legitimate exclusion: test-generator.md (adapted per stack).
mcount=0
for cf in core/commands/*.md core/agents/*.md core/templates/*.md core/rules/*.md; do
  rel=${cf#core/}                       # e.g. commands/sdd-spec.md
  [ "$rel" = "agents/test-generator.md" ] && continue
  mcount=$((mcount+1))
  base=$(hashf "$cf")
  for s in $SKILLS; do
    sf="skills/$s/reference/$rel"
    if [ ! -f "$sf" ]; then fail "$s: core master missing: $rel"
    elif [ "$(hashf "$sf")" != "$base" ]; then fail "$s: $rel differs from core/ (drift)"; fi
  done
done
# 6b. Shared files OUTSIDE core that must be identical across the relevant skills.
#     Legitimate exclusions (per-stack divergence): 10-code-conventions, 11-tests-strategy,
#     12-quality-gates, api-contracts; migration-guard diverges between the symfony pair
#     but is shared verbatim between the two java skills (hash-checked in the java group).
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
# 6c. Command↔agent duplicated logic: the canonical AC format must be identical
#     wherever it is stated (commands, agents, templates), or the copies drift silently.
AC_FORMAT='the system \[action\] and \[expected result\]'
for f in core/templates/spec.md core/agents/spec-writer.md core/commands/sdd-spec.md core/commands/sdd-review.md; do
  grep -q "$AC_FORMAT" "$f" 2>/dev/null || fail "AC format drift: canonical string missing in $f"
done
c=$(grep -rc "the system \[action\] and \[[a-z ]*result\]" core --include='*.md' 2>/dev/null | awk -F: '$2>0{n+=$2}END{print n+0}')
canon=$(grep -rc "$AC_FORMAT" core --include='*.md' 2>/dev/null | awk -F: '$2>0{n+=$2}END{print n+0}')
[ "$c" -eq "$canon" ] || fail "AC format drift: $((c-canon)) non-canonical variant(s) of the AC format in core/"
check_shared "angular" "sdd-symfony-angular sdd-angular-node sdd-java-angular" \
  commands/angular-component.md commands/angular-service.md commands/angular-test.md \
  rules/angular-conventions.md
check_shared "symfony" "sdd-php-symfony sdd-symfony-angular" \
  commands/symfony-entity.md commands/symfony-service.md commands/symfony-controller.md commands/symfony-test.md \
  rules/doctrine-conventions.md
check_shared "java" "sdd-java-backend sdd-java-angular" \
  commands/java-entity.md commands/java-service.md commands/java-controller.md commands/java-test.md \
  rules/jpa-conventions.md rules/migration-guard.md
[ $err -eq $before ] && ok "$mcount core masters + angular/symfony/java groups identical (hash)"

# =====================================================================
echo ""
if [ $err -eq 0 ]; then echo "✅ AUDIT OK — no inconsistency detected."; else echo "❌ AUDIT: $err problem(s) detected."; fi
exit $err
