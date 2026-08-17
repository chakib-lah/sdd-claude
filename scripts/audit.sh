#!/usr/bin/env bash
# SDD Claude consistency audit — run after any change to the package.
# Usage: bash scripts/audit.sh   (from any directory)
#
# Checks that the framework is installable, consistent, complete and duplication-free:
#   1. Structure       — skills tree + global-agents + installers
#   2. Completeness    — 17 core commands + 5 SDD agents per skill, 9 global agents
#   3. Ghost refs      — every referenced rule/command actually exists
#   4. Delegations     — test-generator / plan-architect consistent
#   5. Docs            — command count, skills documented, version/CHANGELOG/tag
#                        coherence, anatomy↔template sync, write-step↔template sync,
#                        stack-agnostic Layer 1, extension-guide command list complete
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
# template ↔ canonical-rule anatomy sync: a template gaining a section without
# 00-sdd-framework's anatomy following was a known defect class.
# Wiring enumeration (the invariant): 00-sdd-framework carries exactly 3 "Anatomy
# of" sections (spec, plan, tasks) — the 3 lifecycle artifacts — and all 3 are
# wired below. The other templates deliberately carry NO anatomy and are not wired:
# notes.md is an explicitly free-form logbook, sdd-readme.md is a live index seeded
# once, jira-story-*/spec-doc-* are export trames, not workflow artifacts.
# Exact match on the bold entry name (**Title**) avoids substring collisions.
anat=$(awk '/^## Anatomy of a spec/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r t; do
  printf '%s\n' "$anat" | grep -qF "**$t**" \
    || fail "00-sdd-framework: spec anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/spec.md)
anat=$(awk '/^## Anatomy of a tasks.md/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r t; do
  printf '%s\n' "$anat" | grep -qF "**$t**" \
    || fail "00-sdd-framework: tasks anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/tasks.md)
anat=$(awk '/^## Anatomy of a plan/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r t; do
  printf '%s\n' "$anat" | grep -qF "**$t**" \
    || fail "00-sdd-framework: plan anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/plan.md)
# command → template: every #### sub-block of a "Write <file>" step names either
# Frontmatter or a real ## section of the template it fills (a command writing
# a section name the template abandoned was a known defect class).
# Wiring enumeration (the invariant): the pattern '^### [0-9]+[a-z]?\. Write '
# matches exactly 4 command files (sdd-spec, sdd-plan, sdd-tasks, retro-spec)
# and all 4 are wired below — re-run the enumeration when adding a command:
#   grep -ln '^### [0-9]\+[a-z]\?\. Write ' core/commands/*.md
# The [a-z]? covers lettered steps ("5b.", "5c.") which already exist in the
# corpus and which the previous pattern silently skipped.
check_write_step(){
  local cmd="$1" tpl="$2"
  while IFS= read -r b; do
    [ "$b" = "Frontmatter" ] && continue
    grep -qxF "## $b" "core/templates/$tpl" \
      || fail "$cmd: write-step block '#### $b' names no section of templates/$tpl"
  done < <(awk '/^### [0-9]+[a-z]?\. Write /{f=1;next} /^### /{f=0} f' "core/commands/$cmd" | sed -n 's/^#### //p')
}
check_write_step sdd-spec.md  spec.md
check_write_step sdd-plan.md  plan.md
check_write_step sdd-tasks.md tasks.md
check_write_step retro-spec.md spec.md
# template → agent skeleton: every ## section of the template must appear in the
# full-file skeleton the delegated agent emits (a section added to the template
# without the agent following was a known defect class). Wiring enumeration:
#   - plan-architect is the ONLY agent emitting a full-file ```markdown skeleton
#     with ## sections → wired against plan.md
#   - task-decomposer's skeleton is a PHASE FRAGMENT (### Phase 1: …), not a whole
#     tasks.md → comparing it to ## sections would be a false positive by design
#   - spec-writer, code-reviewer, test-generator emit no skeleton at all
skel=$(awk '/```markdown/{f=1;next} /```$/{f=0} f' core/agents/plan-architect.md)
while IFS= read -r t; do
  printf '%s\n' "$skel" | grep -qxF "## $t" \
    || fail "plan-architect: skeleton missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/plan.md)
# Layer 1 must stay stack-agnostic: the methodology rules may name none of the
# technologies the extension guide itself forbids. Scope enumeration (deliberate):
#   - core/rules/*.md — the "process files" the guide's rule targets. WIRED.
#   - core/commands/ and core/agents/ — carry LEGITIMATE stack mentions and stay out:
#     test-generator is stack-adapted by design (already excluded from the hash net),
#     sdd-upgrade must name Layer-2 file patterns, task-decomposer illustrates
#     per-stack task categories, retro-spec/sdd-changelog use worked examples,
#     code-reviewer's stack anti-patterns are a known backlog item (move to Layer 2).
#   - core/README.md, core/extension-guide.md, core/examples/ — package docs, not
#     deployed process files.
# Case-insensitive (a lowercase "symfony-7-4" is still a name). Multi-word names
# supported. An EMPTY derived list would turn this net into a silent ✓ — fatal.
# The list covers TWO classes, both written in extension-guide's "No mention of"
# lines: framework names (PHPUnit…) and tool/package-manager names (composer,
# npm, gradle, npx — a past defect: 03-security.md named composer/npm audit for
# six versions and this net stayed green because only frameworks were listed).
# Source of the tool names: the skills' own Layer 2 rules (10/11/12), where
# each of these four is actually written — not an invented list.
FORBIDDEN=$(grep '^- No mention of' core/extension-guide.md | grep -oE '"[^"]+"' | tr -d '"')
[ -n "$FORBIDDEN" ] || fail "stack-agnostic net: derived forbidden-technology list is EMPTY (check extension-guide's 'No mention of' lines)"
while IFS= read -r w; do
  [ -n "$w" ] || continue
  for f in core/rules/*.md; do
    grep -qi "$w" "$f" && fail "$(basename "$f") names a forbidden technology: $w"
  done
done <<EOF_FORBIDDEN
$FORBIDDEN
EOF_FORBIDDEN
# one skill, one stack: test-generator.md and 11-tests-strategy.md may name only
# the test frameworks of their skill's own stack. Five of six test-generators
# shipped the same multi-stack skeleton for six versions — this file is excluded
# from the hash net (adapted per skill), which is exactly why nothing reported it.
# Wiring enumeration (the invariant):
#   - all 6 skills wired, for BOTH files (11-tests-strategy is the same class and
#     is currently clean — wired at zero cost to keep it that way)
#   - core/agents/test-generator.md NOT wired: it is the generic multi-stack base
#     each skill adapts — naming several stacks is its purpose
# Boundary-guarded case-insensitive match to avoid substring collisions.
check_stack_purity(){
  local skill="$1"; shift
  local w f
  for f in "skills/$skill/reference/agents/test-generator.md" "skills/$skill/reference/rules/11-tests-strategy.md"; do
    [ -f "$f" ] || { fail "$skill: missing $(basename "$f")"; continue; }
    for w in "$@"; do
      grep -qiE "(^|[^a-zA-Z])${w}([^a-zA-Z]|\$)" "$f" \
        && fail "$skill: $(basename "$f") names an out-of-stack framework: $w"
    done
  done
}
check_stack_purity sdd-php-backend     jest vitest playwright cypress jasmine "testing library" supertest junit mockito
check_stack_purity sdd-php-symfony     jest vitest playwright cypress jasmine "testing library" supertest junit mockito
check_stack_purity sdd-angular-node    phpunit junit mockito
check_stack_purity sdd-symfony-angular junit mockito
check_stack_purity sdd-java-backend    phpunit jest vitest playwright cypress jasmine "testing library" supertest
check_stack_purity sdd-java-angular    phpunit
# the toolkit states WHAT must be green — it never ships a CI pipeline (owner's
# scope decision). Three markers prove a pipeline; anything else is
# application/methodology configuration and must NOT fire:
#   (a) any shipped *.yml/*.yaml file under core/ or skills/
#   (b) a "stages:" line at column 0 inside a shipped .md
#   (c) a "# .gitlab-ci.yml" marker, or a two-space-indented "stage:" line
#       (the shape of a GitLab job definition; app config never has it)
# Wiring enumeration (the invariant): all .md under core/ and skills/ (masters
# included — read-only), plus the file-tree check. Deliberately NOT caught:
# a GitHub-Actions/Jenkins pipeline (the toolkit was only ever GitLab-oriented);
# kept config blocks (springdoc:, nelmio_*, app.cors:, SDD frontmatter) match
# none of the three markers — that non-firing is part of the contract.
c=$(find core skills -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l)
[ "$c" -eq 0 ] || fail "shipped YAML file(s) found — the toolkit must not ship pipelines ($c file(s))"
while IFS= read -r hit; do
  fail "CI pipeline content in a shipped file: $hit"
done < <(grep -rnE '^stages:|^# \.gitlab-ci\.yml|^  stage: ' core skills --include='*.md' 2>/dev/null)
# every shipped command is named in the extension guide (its "17 commands"
# list once held 15 — a wrong LIST is invisible to the numeric count check;
# anchored match: a missing /sdd-spec must not be covered by /sdd-spec-check).
# Wiring enumeration (the invariant): the pattern is core/commands/*.md and the
# loop below iterates that same glob — matched set = wired set by construction.
for c in core/commands/*.md; do
  n=$(basename "$c" .md)
  grep -qE "/$n"'([^a-z-]|$)' core/extension-guide.md \
    || fail "extension-guide does not name command /$n"
done
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
# 6d. AC identifiers: every file that STATES the canonical AC format must
#     show it under a stable identifier (AC-N / AC-1), or new specs ship anonymous
#     ACs and numbering degrades to positional — which /sdd-clarify silently breaks
#     the first time it adds one. Wiring enumeration (the invariant): the 4 files
#     of the 6c list (the authoring + consuming sites of the canonical string) are
#     all wired; sdd-hotfix authors fixed non-canonical ACs and is wired on the
#     bare identifier; retro-spec numbers reconstructed ACs in prose (no example
#     line to grep) — stated, not wired.
for f in core/templates/spec.md core/agents/spec-writer.md core/commands/sdd-spec.md core/commands/sdd-review.md; do
  grep -qE 'AC-(N|1): When' "$f" \
    || fail "AC identifier missing next to the canonical format in $f"
done
grep -q 'AC-1' core/commands/sdd-hotfix.md \
  || fail "sdd-hotfix: template ACs lost their AC-N identifiers"
# 6e. tasks phase-block fields ↔ anatomy: the Rollback field once shipped
#     with zero consumers because nothing forced 00-sdd-framework's anatomy
#     to follow the template's phase-block fields. Field list DERIVED from
#     templates/tasks.md itself (the top-level bold bullets of the first
#     "### Phase" example block); each must appear in "Anatomy of a tasks.md".
#     Wiring enumeration: tasks.md is the only template with a phase block
#     (spec/plan carry none — not wired). Empty derived list = fatal.
#     SYNC IS TWO-WAY (added at cycle close, proven one-way by its own negative
#     test): template → anatomy below, then anatomy → template — a field the
#     anatomy declares must still exist in the template, or the method lost it.
pf=$(awk '/^### Phase 1:/{f=1;next} f&&/^- \[ \]/{exit} f' core/templates/tasks.md | sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' | sort -u)
[ -n "$pf" ] || fail "phase-field net: derived field list is EMPTY (check templates/tasks.md phase block)"
anat=$(awk '/^## Anatomy of a tasks.md/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r fld; do
  [ -n "$fld" ] || continue
  printf '%s\n' "$anat" | grep -qF "**$fld**" \
    || fail "00-sdd-framework: tasks anatomy missing phase-block field: $fld"
done <<EOF_PF
$pf
EOF_PF
af=$(printf '%s\n' "$anat" | sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' | sort -u)
while IFS= read -r fld; do
  [ -n "$fld" ] || continue
  printf '%s\n' "$pf" | grep -qxF "$fld" \
    || fail "templates/tasks.md lost phase-block field still declared by the anatomy: $fld"
done <<EOF_AF
$af
EOF_AF
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
