#!/usr/bin/env bash
# SDD Claude consistency audit — run after any change to the package.
# Usage: bash scripts/audit.sh   (from any directory)
#
# Checks that the framework is installable, consistent, complete and duplication-free:
#   1. Structure       — skills tree + global-agents + installers
#   2. Completeness    — every listed core command + SDD agent per skill, every global agent (counts computed from the name lists below)
#   3. Ghost refs      — every referenced rule/command actually exists
#   4. Delegations     — test-generator / plan-architect consistent
#   5. Docs            — command count, skills documented, version/CHANGELOG/tag
#                        coherence, anatomy↔template sync, write-step↔template sync,
#                        stack-agnostic Layer 1, extension-guide command list complete
#   6. Anti-drift      — core masters + shared groups byte-identical (hash)
set -uo pipefail
# Harness invariant — under `pipefail`, NO pipeline in this file may feed
# `grep -q`: grep -q exits at the first match, closes the pipe early, SIGPIPEs
# the producer (exit 141) and turns a true check into a nondeterministic
# failure. Real measurement on a materialized section variable falsified the old "small printf/echo
# producers are exempt" assumption — the ban is unconditional for EVERY producer
# (awk, printf, echo, find, sed, cat, ...). Match materialized variables with
# the shell-native helpers below (contains/has_line, [[ =~ ]]), run structural
# checks in one autonomous awk process, and keep `grep -q pattern file` for
# files: a standalone grep with no upstream producer cannot SIGPIPE anything
# and stays allowed.
cd "$(dirname "$0")/.." || exit 1   # move to the toolkit root
err=0
say(){ printf '%s\n' "$*"; }
fail(){ printf '  ✗ %s\n' "$*"; err=$((err+1)); }
ok(){ printf '  ✓ %s\n' "$*"; }
# Deterministic in-process replacements for the banned `producer | grep -q`
# pipelines: both match a MATERIALIZED shell variable, no subprocess, no pipe.
# contains = substring anywhere (grep -qF equivalent for newline-free needles);
# has_line = exact whole-line match (grep -qxF equivalent).
contains(){ case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
has_line(){
  case "$1" in
    "$2"|"$2"$'\n'*|*$'\n'"$2"|*$'\n'"$2"$'\n'*) return 0;;
    *) return 1;;
  esac
}
# Self-guard: the harness invariant above is machine-enforced on this file
# itself — executable scripts/audit.sh must contain NO pipeline whose
# downstream consumer is `grep -q` (any -q-carrying option cluster). Detected
# forms: `cmd | grep -q…` on one line; a line ending in `|` (pipeline split
# before the consumer) continued by a `grep -q…` line; a continuation line
# starting with `| grep -q…` (pipeline split after a backslash). Comment lines
# are exempt, so this description and the invariant above cannot fire it; the
# detection regexes are assembled from fragments so their own source lines
# never form the forbidden pattern. Standalone `grep -q pattern file` has no
# upstream producer and is deliberately not matched; grep -c / grep -o drain
# their input and are safe.
sg=$(awk '
  BEGIN {
    gq = "grep[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*-[[:alpha:]]*q"
    pipe_gq  = "[^|][|][[:space:]]*" gq
    lead_gq  = "^[[:space:]]*[|][[:space:]]*" gq
    bare_gq  = "^[[:space:]]*" gq
    tail_pipe    = "[^|][|][[:space:]]*\\\\?$"
    tail_dblpipe = "[|][|][[:space:]]*\\\\?$"
  }
  /^[[:space:]]*#/ { prev_pipe = 0; next }
  {
    if ($0 ~ pipe_gq || $0 ~ lead_gq) print NR ": pipeline feeding grep -q"
    else if (prev_pipe && $0 ~ bare_gq) print NR ": split-line pipeline feeding grep -q"
    prev_pipe = ($0 ~ tail_pipe && $0 !~ tail_dblpipe) ? 1 : 0
  }' scripts/audit.sh)
if [ -n "$sg" ]; then
  printf '%s\n' "$sg"
  fail "audit self-guard: pipeline feeding early-exiting grep -q in executable audit logic (see harness invariant above)"
fi
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
  for d in agents commands rules templates upgrade; do
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
  # Fresh-install disposition contract (anchor-based bounded net — see the Known-Limits
  # Register): every SKILL.md must carry the ownership-labeling block, the non-blocking
  # clarification semantics, the semantic-disposition contract and the canonical
  # Layer-3 fresh-install owners; and must not assert frontend/backend drift as a fact.
  for a in 'never present them as skill-owned' 'non-blocking developer choices' 'Semantic disposition — classify every finding' 'project-git-workflow.md' 'project-security.md'; do
    grep -qF -- "$a" "skills/$s/SKILL.md" || fail "$s: SKILL.md missing fresh-install contract anchor: $a"
  done
  grep -qE 'drifting from the backend' "skills/$s/SKILL.md" && fail "$s: SKILL.md asserts drift as fact (must be a drift risk unless a comparison proved it)"
  # Agent ownership: exactly 4 universal framework-owned agents; test-generator
  # is stack-adapted and selected-skill-owned — never framework-owned/Layer 1.
  grep -qF -- '4 universal SDD agents' "skills/$s/SKILL.md" || fail "$s: SKILL.md missing the 4-universal-agents ownership anchor"
  grep -qF -- 'stack-adapted `test-generator` agent' "skills/$s/SKILL.md" || fail "$s: SKILL.md missing the selected-skill-owned test-generator anchor"
  awk '/test-generator/ && tolower($0) ~ /framework-owned|layer 1/{found=1} END{exit !found}' "skills/$s/SKILL.md" && fail "$s: SKILL.md classifies test-generator as framework-owned/Layer 1"
  awk '/5 SDD agents/ && tolower($0) ~ /framework-owned|layer 1/{found=1} END{exit !found}' "skills/$s/SKILL.md" && fail "$s: SKILL.md flattens the 5 agents into framework ownership"
  # Layer-3 disposition contradiction net (bounded — see the Known-Limits
  # Register): a correct Class A-E anchor does NOT excuse contradictory active prose —
  # a Layer-3 disposition line must never promote detected/observed technical state.
  awk '/Layer 3/ && tolower($0) ~ /detected |observed |patterns in use|repository shape/{found=1} END{exit !found}' "skills/$s/SKILL.md" && fail "$s: SKILL.md promotes detected/observed technical state to Layer 3"
  # Runtime reasoning contracts (anchor-based bounded nets, see the Known-Limits
  # Register): the final Layer-3 sanitization gate and the evidence-dimension separation
  # must ship in every installer; known contradictory formulations must be absent.
  for a in 'Final Layer-3 sanitization gate' 'Independent evidence dimensions' 'never proves the capability is unconfigured' 'do not create' ; do
    grep -qiF -- "$a" "skills/$s/SKILL.md" || fail "$s: SKILL.md missing runtime-reasoning anchor: $a"
  done
  grep -qiE '(universal|layer-? ?1)[^.]*(may|can) (remain|be restated|be kept|stay)[^.]*(project-|layer-? ?3)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a universal invariant to remain in Layer 3"
  grep -qiE '(task names?|technical (current )?state|rediscoverable state)[^.]*(may|can) be persisted' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows rediscoverable technical state to be persisted"
  grep -qiE '(missing|absent|no)[^.]*(artifact|lock ?file)[^.]*(means|implies|=>)[^.]*(not configured|disabled|unconfigured)' "skills/$s/SKILL.md" && fail "$s: SKILL.md infers configuration absence from artifact absence"
  # Final proposal materialization (anchor-based bounded nets, see the
  # Known-Limits Register): the rendered proposal must be the normalized one; known
  # contradiction formulations are rejected.
  for a in 'render only the normalized result' 'One final disposition per clause' 'moved, never copied' 'neither displayed nor created' 'second manual sanitization pass must never be needed'; do
    grep -qiF -- "$a" "skills/$s/SKILL.md" || fail "$s: SKILL.md missing proposal-materialization anchor: $a"
  done
  grep -qiE '(raw|intermediate) candidate[^.]*(may|can) be (rendered|displayed|shown)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows rendering a raw candidate set"
  grep -qiE '(may|can) (remain|stay|appear|be kept) (in|under) (both|two|multiple)[^.]*owners' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows one clause under multiple subject owners"
  grep -qiE 'relocat[a-z]*[^.]*(may|can) (remain|stay|be kept|also be copied)|(may|can) (also )?be copied (to|into|across)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a relocated clause to remain/copy in its source owner"
  grep -qiE 'empty (candidate|project rule)[^.]*(may|can) (remain|be displayed|be created|be kept)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows an empty candidate in the proposal"
  grep -qiE '(may|can) appear (as|in) both (kept|KEPT) and (removed|REMOVED)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a clause in both kept and removed sets"
  # Approved-set materialization (anchor-based bounded nets, see the Known-Limits
  # Register): approval freezes the Layer-3 set; Phase 4 writes only that set and a
  # post-write fidelity check is mandatory; known reconstruction prose is rejected.
  for a in 'Approval freezes the Layer-3 set' 'immutable for the rest of the install run' 'materialization — never reclassification' 'source of truth for what gets written' 'Post-write fidelity check' 'never re-run to add content'; do
    grep -qiF -- "$a" "skills/$s/SKILL.md" || fail "$s: SKILL.md missing approved-set materialization anchor: $a"
  done
  grep -qiE 'enrich (the )?(Layer-? ?3|project rules?)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows enriching Layer 3 from discovery"
  grep -qiE '(violation|gap|follow-?up)s?[^.]*(may|can) be (documented|persisted|recorded|written) as[^.]*(exception|Layer-? ?3|project rule)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows promoting a violation/gap into a Layer-3 exception"
  grep -qiE '(may|can) be added[^.]*for completeness' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows adding rediscoverable context for completeness"
  grep -qiE '(FOLLOW_UP|REDISCOVER_ON_DEMAND|REMOVED_L[12])[^.]*(may|can) (become|be promoted|transition|be reclassified)[^.]*(KEPT|Layer-? ?3)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a post-approval disposition transition"
  # Semantic boundaries (anchor-based bounded nets, see the Known-Limits
  # Register): semantic-claim atomicity before disposition (one independently meaningful
  # assertion = one disposition; attached rediscoverable evidence never rides inside kept
  # policy); choice validity before display (an option overriding/negating Layer 1/2 or
  # redefining the selected-skill target baseline is INVALID_OPTION, never shown; brownfield
  # preservation never redefines the target for new work); verbatim immutable
  # APPROVED_LAYER3_RECORDS at approval; renderer non-authorship with the semantic-vs-
  # structural classification and the render-time amend/re-approve path; post-write
  # fidelity compared against the pre-write records, never reconstructed intent.
  for a in 'one independently meaningful assertion = one disposition' 'merely because it was attached to a durable decision' 'ownership validation precedes user choice presentation' 'INVALID_OPTION' 'brownfield preservation does not redefine the target baseline' 'never negate or redefine Layer-1 or Layer-2 target policy for new work' 'APPROVED_LAYER3_RECORDS' 'captured verbatim' 'transcription plus formatting, never semantic authorship' 'semantic content, never structural formatting' 'stop materializing that rule' 'ask the developer to re-approve' 'against those same pre-write records'; do
    grep -qiF -- "$a" "skills/$s/SKILL.md" || fail "$s: SKILL.md missing semantic-boundary anchor: $a"
  done
  grep -qiE '(mixed|mixing|combined|combining)[^.]*(may|can) (remain|stay|survive)[^.]*(KEPT|kept)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a mixed-disposition clause to survive as one KEPT clause"
  grep -qiE '(counts?|paths?|versions?|observed values?|inventor(y|ies))[^.]*(may|can) (ride|survive|remain|stay|be kept|be persisted)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows rediscoverable evidence to ride inside kept policy"
  grep -qiE 'layer-? ?3[^.]*(may|can)[^.]*(override|negate|take precedence)[^.]*layer-? ?[12]' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows Layer 3 to override Layer 1/2"
  grep -qiE '(option|choice)[^.]*(may|can) (override|negate|redefine)[^.]*(layer-? ?[12]|universal|target baseline)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows offering a choice that overrides Layer 1/2"
  grep -qiE '(offer|present|display|propose|show)[a-z]*[^.]*(option|choice)[^.]*layer-? ?3[^.]*(overrid|negat|take precedence)[a-z]*[^.]*layer-? ?[12]' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows presenting an option where Layer 3 overrides Layer 1/2"
  grep -qiE '(legacy|frozen migration|exception)s?[^.]*(may|can) (redefine|override|negate)[^.]*(target|layer-? ?[12])' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a legacy exception to redefine the Layer-2 target"
  grep -qiE 'render[a-z]*[^.]*(may|can) (clarify|complete|enrich|repair|add|extend|broaden|narrow)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows the renderer to author semantic content"
  grep -qiE '(responsibilit|accountabilit|carve-?out|rationale)[a-z-]*s?( statements?)?[^.]*(is|are|remains?|counts? as|treated as) (structural|formatting|plain formatting|non-semantic)' "skills/$s/SKILL.md" && fail "$s: SKILL.md classifies semantic content as structural formatting"
  grep -qiE '(fidelity|verification|comparison|baseline)[^.]*(may|can)[^.]*(reconstruct|remember|infer|recall)' "skills/$s/SKILL.md" && fail "$s: SKILL.md allows a reconstructed-intent fidelity baseline"
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
  TOOLS_RE='^tools: \[[A-Z][A-Za-z]*(, [A-Z][A-Za-z]*)*\]$'
  [[ "$t" =~ $TOOLS_RE ]] \
    || fail "invalid tools frontmatter (expected e.g. 'tools: [Read, Bash]'): $f"
done
for d in skills/*/; do
  s=$(basename "$d")
  contains " $SKILLS " " $s " || fail "skill not declared in the reference list/installer: $s"
done
[ $err -eq $before ] && ok "tree of the 6 skills + global-agents + installers conforms"

# =====================================================================
NCMD=$(echo $CORE_CMDS | wc -w); NSAG=$(echo $SDD_AGENTS | wc -w); NGAG=$(echo $GLOBAL_AGENTS | wc -w)
say "== 2. Completeness ($NCMD core commands + $NSAG SDD agents / skill, $NGAG global agents) =="
before=$err
for c in $CORE_CMDS; do [ -f "core/commands/$c.md" ] || fail "core: missing command: $c"; done
for a in $SDD_AGENTS; do [ -f "core/agents/$a.md" ]   || fail "core: missing SDD agent: $a"; done
for s in $SKILLS; do
  for c in $CORE_CMDS; do [ -f "skills/$s/reference/commands/$c.md" ] || fail "$s: missing core command: $c"; done
  for a in $SDD_AGENTS; do [ -f "skills/$s/reference/agents/$a.md" ]   || fail "$s: missing SDD agent: $a"; done
done
for a in $GLOBAL_AGENTS; do [ -f "global-agents/$a.md" ] || fail "missing global agent: $a"; done
[ $err -eq $before ] && ok "$NCMD core commands + $NSAG SDD agents present everywhere, $NGAG global agents present"

# =====================================================================
say "== 3. Ghost references (cited rules / commands actually exist) =="
before=$err
# 3a. historically deleted files that must no longer be cited
for t in sdd-methodology.md 50-team-templates.md; do
  c=$(grep -rl "$t" core skills 2>/dev/null | wc -l)
  [ "$c" -eq 0 ] || fail "remaining ghost reference: $t ($c files)"
done
# 3a-ter. renamed rules (v1.3.0 slots): old names may appear ONLY in sdd-upgrade.md
#         (its migration map documents them); anywhere else is drift.
#         CHANGELOG.md is historical evidence and is deliberately outside this net.
for t in 05-constitution.md 20-git-conventions.md 50-security.md 30-tests-strategy.md 40-quality-gates.md 02-git-conventions.md 03-security.md 04-code-quality.md; do
  c=$(grep -rlF -- "$t" core skills 2>/dev/null | grep -v '/sdd-upgrade-procedure\.md$' | wc -l)
  [ "$c" -eq 0 ] || fail "renamed rule still cited under its old name: $t ($c files)"
done
# 3a-quater. Layer-2 canonical-decade old names (pre-decade aliases). The old names are
# SUBSTRINGS of their canonical successors (jpa-conventions.md ⊂ 30-jpa-conventions.md),
# so the net matches the old token only when NOT already carrying its canonical numeric
# prefix ([^-0-9] before it). The allowance is CONTEXT-SCOPED, never file-scoped:
#   - outside sdd-upgrade.md: any occurrence is drift;
#   - inside sdd-upgrade.md: aliases are allowed ONLY within the §0b migration-map
#     section (from the '### 0b.' heading to the next '### ' heading) where they are
#     migration-map DATA; the same token in any other sdd-upgrade prose fails.
# CHANGELOG.md stays outside this net (historical evidence).
L2_OLD_RE='(^|[^-0-9])(node-conventions|doctrine-conventions|jpa-conventions|angular-conventions|api-contracts|shared-types|refactoring-guard|legacy-rules|migration-guard)\.md'
for t in node-conventions doctrine-conventions jpa-conventions angular-conventions api-contracts shared-types refactoring-guard legacy-rules migration-guard; do
  c=$(grep -rlE -- "(^|[^-0-9])$t\.md" core skills 2>/dev/null | grep -v '/sdd-upgrade-procedure\.md$' | wc -l)
  [ "$c" -eq 0 ] || fail "renamed Layer-2 rule still cited under its old name: $t.md ($c files)"
done
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  c=$(awk '/^### /{inmap=(/^### 0b\./)?1:0} !inmap{print}' "$f" | grep -cE -- "$L2_OLD_RE")
  [ "$c" -eq 0 ] || fail "historical Layer-2 alias outside the §0b migration map: $f ($c line(s))"
done
# 3a-quinquies. Bounded stale-naming prose net (SECONDARY guard — boundary documented in
# the Known-Limits Register): catches only the known obsolete formulations reproduced
# around v1.16.0; it is deliberately NOT a general semantic prose checker.
for pat in 'unnumbered file' 'unnumbered rule' 'unnumbered stack' 'may be numbered'; do
  c=$(grep -rli -- "$pat" core skills 2>/dev/null | wc -l)
  [ "$c" -eq 0 ] || fail "known stale Layer-2 naming formulation ('$pat') in active prose ($c files)"
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
  # Layer-3 canonical files are PROJECT-OWNED and never shipped by the framework:
  # commands legitimately cite them (project-constitution consumers, effective
  # Git-policy resolution) while no skill ships them. Enumerated allowlist —
  # extend only for canonical Layer-3 names documented by the architecture.
  # 01-constitution.md is the retired LEGACY constitution carrier: it ships in no
  # reference anymore and is cited only by /sdd-upgrade's step 2c migration.
  # project-language.md is the retired LEGACY working-language alias: same status —
  # it ships nowhere and is cited only by /sdd-upgrade's step 0b contract and its
  # step 2d / 4c-bis canonicalization gates, which exist precisely to retire it.
  case "$r" in project-constitution.md|project-git-workflow.md|project-architecture.md|project-testing.md|project-quality.md|project-security.md|project-working-language.md|project-language.md|01-constitution.md) continue;; esac
  { [ -f "core/rules/$r" ] || [ -n "$(find skills -path "*/reference/rules/$r" 2>/dev/null)" ]; } \
    || fail "referenced rule not found anywhere: $r"
done
# 3c. every cited command `.claude/commands/X.md` exists in core/commands OR in a skill
for c in $(grep -rhoE "\.claude/commands/[a-z0-9-]+\.md" core skills 2>/dev/null | sed 's|.*/||' | sort -u); do
  { [ -f "core/commands/$c" ] || [ -n "$(find skills -path "*/reference/commands/$c" 2>/dev/null)" ]; } \
    || fail "referenced command not found anywhere: $c"
done
[ $err -eq $before ] && ok "no ghost references (rules + commands resolved)"

# =====================================================================
say "== 4. Agent delegations (test-generator / plan-architect) =="
before=$err
for s in $SKILLS; do
  pa_desc=$(grep -m1 '^description:' "skills/$s/reference/agents/plan-architect.md" 2>/dev/null)
  contains "$pa_desc" '/sdd-plan' \
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
# Command-count coherence: every DECLARED command count must equal the COMPUTED one — the source
# of truth is ls core/commands/*.md | wc -l, never a blacklist of known-wrong
# values (the old (9|12|14|15) net proved "no known-bad value", not "17", and
# let "16 universal commands" pass green). Declaration grammar, from the real
# corpus (measured 2026-08-20): a number followed by up to two qualifiers from
# {universal, SDD, core, existing} then "command(s)"/"commande(s)" — covers
# "17 commands", "17 SDD commands", "17 universal commands",
# "17 universal SDD commands", "17 core commands", "17 existing universal
# commands". Enumerated FALSE POSITIVE, deliberately excluded: "Layer N
# commands" (sdd-upgrade.md — a layer label, not a count); "Layer <n>" is
# stripped from the line before extraction. Wiring enumeration (the invariant):
# every .md under core/ and skills/ plus README.md and INSTALL.md — the same
# set the pattern is greped over; nothing matched is left unchecked.
# ((^|[^0-9]) instead of \b: word boundaries are a GNU extension, inert under BSD grep)
CMD_COUNT=$(ls core/commands/*.md 2>/dev/null | wc -l)
[ "$CMD_COUNT" -gt 0 ] || fail "command-count net: computed count is 0 — core/commands/*.md missing"
CMD_DECL='[0-9]+( (universal|SDD|core|existing)){0,2} (command|commande)s?'
decl_seen=0
while IFS= read -r hit; do
  cfile=${hit%%:*}; rest=${hit#*:}; clineno=${rest%%:*}; cline=${rest#*:}
  cleaned=$(printf '%s' "$cline" | sed -E 's/Layer [0-9]+//g')
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    decl_seen=$((decl_seen+1))
    n=$(printf '%s' "$m" | grep -oE '^[0-9]+')
    [ "$n" -eq "$CMD_COUNT" ] \
      || fail "declared command count $n != computed $CMD_COUNT (ls core/commands/*.md): $cfile:$clineno"
  done < <(printf '%s' "$cleaned" | grep -oE "(^|[^0-9])$CMD_DECL" | grep -oE "$CMD_DECL")
done < <(grep -rnE "(^|[^0-9])$CMD_DECL" core skills README.md INSTALL.md --include='*.md' 2>/dev/null)
[ "$decl_seen" -gt 0 ] || fail "command-count net: no count declaration found anywhere — the net matched nothing (grammar broken?)"
# Universal commands are version-agnostic. MACHINE-ENFORCED boundary
# — no EXPLICIT VERSION TOKEN (vX.Y or X.Y.Z) in a universal command body
# — "added in v1.7.0", "since 1.2.3", "new in v1.8" are all caught by the
# pattern, not by a list of historical phrasings. Release narrative WITHOUT a
# version token ("added in the previous release") remains a semantic rule
# enforced by human review — see the Known-Limits Register in
# core/extension-guide.md. EXCEPT: the enumerated migration/version-handling sections of
# sdd-upgrade.md, which legitimately name versions —
#   "### 0. Locate the toolkit reference"  (the freshness check)
#   "### 0b. Plan pending file renames"    (the rename map + .sdd-version marker)
# The exclusion applies to those two sections of that one file only — never the
# whole file, never another command. Wiring enumeration (the invariant): every
# universal command master (core/commands/*.md) AND its 6 skill copies (same
# basenames under skills/*/reference/commands/); Layer 2 scaffolding commands
# (symfony-*, angular-*, node-*, php-*, java-*) are NOT wired — they may
# legitimately cite stack versions, and they exist only in skills.
while IFS= read -r hit; do
  fail "version narrative in a universal command: $hit"
done < <(for c in core/commands/*.md; do
  b=$(basename "$c")
  for f in "$c" skills/*/reference/commands/"$b"; do
    [ -f "$f" ] || continue
    up=0; [ "$b" = "sdd-upgrade.md" ] && up=1
    awk -v FILE="$f" -v UP="$up" '
      /^### /{sec=$0}
      /v[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+/{
        if (UP == 1 && (sec ~ /^### 0\. Locate the toolkit reference/ || sec ~ /^### 0b\. Plan pending file renames/)) next
        print FILE ":" FNR
      }' "$f"
  done
done)
# Decision-tree coverage: every skill must be documented IN THE DECISION TREE — the check reads
# the actual '## Decision tree' block of skills/README.md, not the whole file
# (the old whole-file grep passed when a skill only appeared in the skills
# table). An empty or missing block is fatal. Wiring enumeration (the
# invariant): all skills of $SKILLS, against that one block.
sp_dt=$(awk '/^## Decision tree/{f=1;next} /^## /{f=0} f' skills/README.md 2>/dev/null)
[ -n "$sp_dt" ] || fail "skills/README.md: '## Decision tree' block missing or empty"
for s in $SKILLS; do
  contains "$sp_dt" "$s" || fail "skills/README.md: $s absent from the '## Decision tree' block"
done
# Version coherence — the canonical current-version CARRIERS must cite
# VERSION exactly. The GUIDE owns the carrier list: derived from the
# '- Current-version carrier: "X"' lines of core/extension-guide.md (section d),
# never hard-coded here. Entries are literal repo-relative file paths — checked
# with -f and grep -F, never interpreted as regex fragments. An EMPTY derived
# list OR a declared carrier missing on disk (e.g. a "READM.md" typo silently
# shrinking coverage) must FAIL LOUDLY. Deliberately NOT wired: every other
# version-looking number (Layer 2 stack versions, CHANGELOG history, the
# sdd-upgrade rename map) — those are outside the deterministic guarantee, as
# the guide's boundary sentence states; whether a NON-carrier may claim a
# current version at all is a different, semantic rule.
v=$(cat VERSION 2>/dev/null)
CARRIERS=$(grep '^- Current-version carrier:' core/extension-guide.md | grep -oE '"[^"]+"' | tr -d '"')
[ -n "$CARRIERS" ] || fail "version-coherence net: derived carrier list is EMPTY (check extension-guide's 'Current-version carrier:' lines)"
# Exact-token citation: the citation must be the version as a WHOLE TOKEN, not a substring
# ("11.8.20" contains "1.8.2" and grep -qF let it pass). Accepted carrier
# grammar: exactly the content of VERSION (digits and dots), delimited on both
# sides by start/end of line or any character that is NOT a digit, a dot or a
# hyphen. Consequences, deliberate: "Version 1.8.3 —" and "← 1.8.3" pass
# (space/EOL delimiters); "11.8.30" and "1.8.30" fail (digit glue); "1.8.3.1"
# fails (dot continues a version); "1.8.3-beta" fails (hyphen starts a
# pre-release suffix — suffixes are NOT part of the accepted grammar: a carrier
# must cite the released version exactly as VERSION states it).
vtok=$(printf '%s' "$v" | sed 's/\./\\./g')
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || { fail "version-coherence net: declared carrier '$f' does not exist as a regular file"; continue; }
  grep -qE "(^|[^0-9.-])${vtok}(\$|[^0-9.-])" "$f" 2>/dev/null || fail "docs: $f does not cite current version $v exactly (stale or glued token)"
done <<EOF_CARRIERS
$CARRIERS
EOF_CARRIERS
# release coherence: VERSION must have a CHANGELOG heading (## [X.Y.Z]).
# "At least one" match — duplicate historical headings are tolerated (legitimate here).
ve=$(printf '%s' "$v" | sed 's/\./\\./g')
grep -qE "^## \[$ve\]" CHANGELOG.md 2>/dev/null \
  || fail "CHANGELOG.md has no '## [$v]' entry for current VERSION"
# release tag: NON-FATAL notice — the toolkit is legitimately consumed as a ZIP
# download or a shallow clone, where tags/history are absent
if git rev-parse --git-dir >/dev/null 2>&1; then
  vtags=$(git tag --list "v$v" 2>/dev/null)
  has_line "$vtags" "v$v" \
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
  contains "$anat" "**$t**" \
    || fail "00-sdd-framework: spec anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/spec.md)
anat=$(awk '/^## Anatomy of a tasks.md/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r t; do
  contains "$anat" "**$t**" \
    || fail "00-sdd-framework: tasks anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/tasks.md)
anat=$(awk '/^## Anatomy of a plan/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
while IFS= read -r t; do
  contains "$anat" "**$t**" \
    || fail "00-sdd-framework: plan anatomy missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/plan.md)
# SYNC IS TWO-WAY (replicating the phase-field model below, which was
# already bidirectional): an anatomy entry the template lost — or never had —
# is method drift too ("Ghost section" stayed green for three versions).
# Reverse direction: every NUMBERED bold entry of each anatomy must exist as a
# '## ' section of the matching template. EXPLICIT EXEMPTION, explicitly tested:
# **Frontmatter** is a numbered entry of all three anatomies but is YAML
# frontmatter, never a '## ' section of any template — same exemption the
# write-step net already grants. Wiring enumeration (the invariant): the same
# 3 anatomy/template pairs as the forward direction above; an anatomy yielding
# ZERO numbered entries would silently pass — fatal.
for sp_pair in "spec:Anatomy of a spec" "plan:Anatomy of a plan" "tasks:Anatomy of a tasks.md"; do
  sp_tpl=${sp_pair%%:*}; sp_anat_h=${sp_pair#*:}
  sp_entries=$(awk "/^## $sp_anat_h/{f=1;next} /^## /{f=0} f" core/rules/00-sdd-framework.md | sed -n 's/^[0-9]*\. \*\*\([^*:]*\)\*\*.*/\1/p')
  [ -n "$sp_entries" ] || { fail "00-sdd-framework: '$sp_anat_h' yields no numbered entries (anatomy moved or reformatted?)"; continue; }
  sp_tsec=$(sed -n 's/^## //p' "core/templates/$sp_tpl.md")
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ "$e" = "Frontmatter" ] && continue
    has_line "$sp_tsec" "$e" \
      || fail "templates/$sp_tpl.md lost section still declared by the anatomy: $e"
  done <<EOF_ANAT
$sp_entries
EOF_ANAT
done
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
  has_line "$skel" "## $t" \
    || fail "plan-architect: skeleton missing template section: $t"
done < <(sed -n 's/^## //p' core/templates/plan.md)
# Layer 1 must stay stack-agnostic: the methodology rules may name none of the
# technologies the extension guide itself forbids. Scope enumeration (deliberate):
#   - core/rules/*.md — the "process files" the guide's rule targets. WIRED.
#   - core/commands/ and core/agents/ — carry LEGITIMATE stack mentions and stay out:
#     test-generator is stack-adapted by design (already excluded from the hash net),
#     sdd-upgrade must name Layer-2 file patterns, task-decomposer illustrates
#     per-stack task categories, retro-spec/sdd-changelog use worked examples
#     (code-reviewer's worked example was stack-neutralised —
#     and the stack anti-pattern CATALOGS moved to Layer 2 —
#     but the directory stays out for the agents above).
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
# The GUIDE owns the vocabulary — derived from the
# '- Stack test vocabulary (<stack>): "X", "Y"' and '- Skill stacks: <skill> = ...'
# lines of core/extension-guide.md, never hard-coded here (the six copy-pasted
# per-skill blacklists were the last instance of the v1.8.0 pattern). For each
# skill, the forbidden set = the vocabulary of every stack the skill does NOT
# declare in its membership line; a vocabulary stack with no member skill
# (python) is forbidden everywhere. The vocabulary is FINITE by design — unknown
# framework names stay semantic (Known-Limits Register in the guide). Entries
# are letters/spaces only (no regex metachars), matched boundary-guarded and
# case-insensitively to avoid substring collisions. Emptiness guards: no stacks,
# an empty per-stack vocabulary, or a skill without a membership line = fatal.
# Wiring enumeration (the invariant):
#   - all 6 skills wired, for BOTH files (11-tests-strategy is the same class and
#     is currently clean — wired at zero cost to keep it that way)
#   - core/agents/test-generator.md NOT wired: it is the generic multi-stack base
#     each skill adapts — naming several stacks is its purpose
SP_STACKS=$(sed -n 's/^- Stack test vocabulary (\([a-z]*\)):.*/\1/p' core/extension-guide.md)
[ -n "$SP_STACKS" ] || fail "stack-purity net: derived stack list is EMPTY (check extension-guide's 'Stack test vocabulary' lines)"
for s in $SKILLS; do
  sp_member=$(sed -n "s/^- Skill stacks: $s = //p" core/extension-guide.md | tr -d ' ')
  [ -n "$sp_member" ] || { fail "stack-purity net: no 'Skill stacks:' membership line for $s in extension-guide"; continue; }
  for st in $SP_STACKS; do
    case ",$sp_member," in *",$st,"*) continue;; esac   # own stack -> allowed
    sp_vocab=$(grep "^- Stack test vocabulary ($st):" core/extension-guide.md | grep -oE '"[^"]+"' | tr -d '"')
    [ -n "$sp_vocab" ] || { fail "stack-purity net: vocabulary for stack '$st' is EMPTY"; continue; }
    while IFS= read -r w; do
      [ -n "$w" ] || continue
      for f in "skills/$s/reference/agents/test-generator.md" "skills/$s/reference/rules/11-tests-strategy.md"; do
        [ -f "$f" ] || { fail "$s: missing $(basename "$f")"; continue; }
        grep -qiE "(^|[^a-zA-Z])${w}([^a-zA-Z]|\$)" "$f" \
          && fail "$s: $(basename "$f") names an out-of-stack framework: $w (stack $st)"
      done
    done <<EOF_SPV
$sp_vocab
EOF_SPV
  done
done
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
# Generated-trailer prohibition: no file the toolkit ships may instruct adding a Co-Authored-By or any
# generated trailer — owner decision, absolute, no exception. Every mention of
# such a trailer in a shipped file must be a PROHIBITION: the same line must
# carry a negation marker (never/forbid/prohibit/strip/no-exception or
# "no exception"/❌ — the regex below matches exactly this list; an earlier revision fixed a
# false positive where the comment named no-exception but the regex lacked it;
# a later fix restricted a separator wildcard that accepted ANY separator — a
# no_exception spelling let a trailer instruction escape as a false negative);
# a line that mentions the trailer without negating it reads as an instruction
# to add it and fails, naming the file. The RULE owns the trailer list: the
# families searched are derived from the '- Forbidden trailer: "X"' lines of
# core/rules/01-git-conventions.md (the master — skill copies are hash-identical
# by net 6), never hard-coded here and never parsed from the prose sentence
# (note: the prose is open-ended; only the canonical list is machine-enforced,
# and the rule states that boundary itself). Entries are LITERAL markers:
# matched with grep -F so a future entry containing '.', '[', '*' or '|'
# cannot silently change the search semantics. An EMPTY derived list would
# turn this net into a silent ✓ — fatal. Wiring enumeration (the invariant):
# every .md under core/, skills/ and global-agents/ — the full set of process
# files the toolkit ships. scripts/ is deliberately excluded: this net itself
# must name the strings in order to hunt them. Case-insensitive. The canonical
# list lines themselves say "Forbidden" and therefore carry their own negation
# marker — they must not fire the net (explicit false-positive fixture).
TRAILERS=$(grep '^- Forbidden trailer:' core/rules/01-git-conventions.md | grep -oE '"[^"]+"' | tr -d '"')
[ -n "$TRAILERS" ] || fail "generated-trailer net: derived canonical trailer list is EMPTY (check 01-git-conventions.md '- Forbidden trailer:' lines)"
while IFS= read -r t; do
  [ -n "$t" ] || continue
  while IFS= read -r hit; do
    line=${hit#*:}; line=${line#*:}
    NEG_RE='never|forbid|prohibit|strip|no[- ]exception|❌'
    [[ "${line,,}" =~ $NEG_RE ]] \
      || fail "generated-trailer instruction: $hit"
  done < <(grep -rniF "$t" core skills global-agents --include='*.md' 2>/dev/null)
done <<EOF_TRAILERS
$TRAILERS
EOF_TRAILERS
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
[ $err -eq $before ] && ok "declared command counts match computed ($CMD_COUNT), carriers cite VERSION, 6 skills documented"

# =====================================================================
say "== 5b. Behavioral contracts (Git policy, working language + legacy migration, source isolation, spec/plan boundary, upgrade, public vocabulary) =="
before=$err
# canonical working-language Layer-3 owner. Every installer must establish
# project-working-language.md; the known legacy alias (project-language.md) is
# upgrade-compatibility data and may appear ONLY in sdd-upgrade.md.
for s in $SKILLS; do
  grep -qF -- 'project-working-language.md' "skills/$s/SKILL.md" \
    || fail "$s: SKILL.md missing the canonical working-language owner (project-working-language.md)"
done
c=$(grep -rlF -- 'project-language.md' core skills --include='*.md' 2>/dev/null | grep -v '/sdd-upgrade-procedure\.md$' | wc -l)
[ "$c" -eq 0 ] || fail "non-canonical working-language filename (project-language.md) outside sdd-upgrade migration data ($c file(s))"
# no SDD/AC traceability metadata may be required or generated in application
# source. Deployable files must not instruct writing AC markers into tests/code.
# The AC ↔ test mapping legitimately lives in SDD artifacts (plan/tasks/verify
# displays) — those formulations do not contain these literal markers.
for pat in 'Covers AC-' '@covers AC-' 'reference the AC it covers in a comment' 'Document each test with the AC'; do
  c=$(grep -rlF -- "$pat" core skills global-agents --include='*.md' 2>/dev/null | wc -l)
  [ "$c" -eq 0 ] || fail "AC-traceability-in-source instruction ('$pat') in a shipped file ($c file(s))"
done
# no source-tracking markers/backlog in product source. Mirror of the
# the generated-trailer negation model: a shipped file may MENTION a tracking marker only on a
# line that negates it (documentation of the prohibition); a line that mentions
# it without negation reads as an instruction/example to add it and fails.
for t in '// LEGACY:' '// MIGRATION:'; do
  while IFS= read -r hit; do
    line=${hit#*:}; line=${line#*:}
    NEG_RE='never|forbid|prohibit|not allowed|no mandatory|❌'
    [[ "${line,,}" =~ $NEG_RE ]] \
      || fail "source-tracking marker instruction: $hit"
  done < <(grep -rniF -- "$t" core skills global-agents --include='*.md' 2>/dev/null)
done
# no comment example carrying a ticket id, and no comment example pointing
# at SDD artifacts for traceability (source comments explain code/domain only).
while IFS= read -r hit; do
  fail "ticket id inside a source-comment example: $hit"
done < <(grep -rniE '^\s*(//|#) .*\(ticket [A-Z]+-?[0-9]*' core skills global-agents --include='*.md' 2>/dev/null)
while IFS= read -r hit; do
  fail "SDD-artifact reference inside a source-comment example: $hit"
done < <(grep -rnE '^\s*// (see |See )?(spec|plan|tasks|notes)\.md' core skills global-agents --include='*.md' 2>/dev/null)
# no commit producer may hard-code its own exact commit-message format:
# a literal `git commit -m "..."` bypasses the effective Git policy resolution
# of 01-git-conventions.md. Placeholder-only forms (`git commit -m "<resolved>"`,
# `git commit -m "$MSG"`) stay allowed; plain `git commit` with the message
# stated as policy-resolved is the sanctioned shape.
while IFS= read -r hit; do
  fail "hard-coded commit message bypassing the effective Git policy: $hit"
done < <(grep -rnE 'git commit -m "[^<$]' core skills global-agents --include='*.md' 2>/dev/null)
# /sdd-upgrade is autonomous when deterministic: no unconditional
# confirmation gate; targeted USER_DECISION_REQUIRED semantics required.
# /sdd-revert is deliberately NOT wired: its destructive confirmation is a
# separate intentional contract.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  grep -qF -- 'Do you confirm this upgrade?' "$f" && fail "unconditional upgrade confirmation: $f"
  grep -qF -- 'Wait for explicit confirmation before modifying anything' "$f" && fail "unconditional pre-write confirmation: $f"
  grep -qF -- 'USER_DECISION_REQUIRED' "$f" || fail "missing USER_DECISION_REQUIRED semantics: $f"
done
# the .sdd-version marker is written LAST: the write instruction (its
# 'create or overwrite' anchor) must appear exactly once, inside the dedicated
# step placed AFTER the post-upgrade verification step (4c). The step-4 apply
# phase carries no marker write anymore.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  n4c=$(awk '/^### 4c\./{print NR; exit}' "$f")
  n4d=$(awk '/^### 4d\. Write the version marker/{print NR; exit}' "$f")
  if [ -z "$n4c" ] || [ -z "$n4d" ] || [ "$n4d" -le "$n4c" ]; then
    fail "version-marker step missing or not after verification: $f"
  else
    wcount=$(grep -c 'create or overwrite' "$f")
    wline=$(grep -n 'create or overwrite' "$f" | head -1 | cut -d: -f1)
    { [ "$wcount" -eq 1 ] && [ "$wline" -gt "$n4d" ]; } \
      || fail "marker write instruction outside the post-verification step: $f ($wcount occurrence(s), first at line ${wline:-none})"
  fi
  grep -qF -- 'LAST filesystem mutation' "$f" || fail "marker-last anchor missing: $f"
done
# spec = WHAT/WHY, plan = HOW. The canonical spec surfaces must not require
# technical Design/impacted files; the plan surfaces must own them. Skill copies
# are guaranteed byte-identical by net 6, so the masters carry the contract.
grep -q '^## Design' core/templates/spec.md && fail "spec template still carries a technical Design section"
sp_anat=$(awk '/^## Anatomy of a spec/{f=1;next} /^## /{f=0} f' core/rules/00-sdd-framework.md)
contains "$sp_anat" '**Design**' && fail "spec anatomy still declares a Design entry"
contains "$sp_anat" '**Functional behavior**' || fail "spec anatomy missing the Functional behavior entry"
grep -qF -- 'Indicate the exact files impacted' core/commands/sdd-spec.md && fail "sdd-spec still requests exact impacted files"
grep -qF -- '#### Design' core/commands/sdd-spec.md && fail "sdd-spec still writes a Design block"
grep -qF -- 'Reference REAL files' core/agents/spec-writer.md && fail "spec-writer still requires real file paths in the spec"
grep -q '^## Technical design' core/templates/plan.md || fail "plan template does not own Technical design"
grep -q '^## Impacted files' core/templates/plan.md || fail "plan template does not own Impacted files"
awk '/^## Anatomy of a plan/{f=1;next} /^## /{f=0} f && index($0,"**Technical design**"){found=1} END{exit !found}' core/rules/00-sdd-framework.md \
  || fail "plan anatomy missing the Technical design entry"
# residual WHAT/WHY leaks. The interview must not ask for implementation
# decisions; clarification answers that settle implementation go to planning context,
# never into the spec; the retro spec carries no exact test/source evidence and no
# generic implementation debt (both live in notes.md). Masters only — copies are
# hash-identical by net 6.
grep -qF -- 'decisions to make' core/commands/sdd-spec.md && fail "sdd-spec still asks for implementation decisions"
grep -qF -- 'Record decisions and their rationale under "Technical constraints"' core/commands/sdd-clarify.md \
  && fail "sdd-clarify still records technical decisions into the spec"
grep -qF -- 'planning context' core/commands/sdd-clarify.md \
  || fail "sdd-clarify missing the implementation-decision planning-context routing"
grep -qE 'tests/[^ ]*::' core/commands/retro-spec.md && fail "retro-spec still shows exact test-path::method evidence in spec content"
grep -qF -- 'exact evidence' core/commands/retro-spec.md || fail "retro-spec missing the exact-evidence-to-notes contract"
grep -qF -- 'implementation debt is NOT spec content' core/commands/retro-spec.md \
  || fail "retro-spec missing the debt-to-notes contract"
grep -qF -- 'Debt lives inside this section' core/commands/retro-spec.md \
  && fail "retro-spec still keeps the technical-debt register inside the spec"
# authority-safe working-language alias migration: /sdd-upgrade must
# classify the legacy alias clause-atomically and route Layer-1/2 clause conflicts
# through a targeted USER_DECISION_REQUIRED, while keeping the compatible case
# deterministic. Regression to an opaque whole-file rename must fail.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  for a in 'never treated as one opaque rename candidate' 'independently meaningful semantic clauses' 'Clause conflicting with Layer 1 or Layer 2' 'targeted at the conflicting clause only' 'deterministic and autonomous'; do
    grep -qF -- "$a" "$f" || fail "working-language alias migration missing authority-safety anchor '$a': $f"
  done
  awk '/Layer-3 canonical working-language alias/{f=1} f && index($0,"USER_DECISION_REQUIRED"){found=1} END{exit !found}' "$f" \
    || fail "working-language alias migration lacks USER_DECISION_REQUIRED semantics: $f"
  grep -qF -- 'moves bytes, never rewrites them' "$f" \
    && fail "working-language alias migration regressed to opaque byte-preserving whole-file rename: $f"
done
# REACHABILITY, not presence. The presence check above proves the alias contract TEXT
# exists; real-project use proved that was insufficient, because the contract sat
# in the step-0b rename-planning section while the main triage flow never invoked
# it. These guards assert the control-flow contract structurally (section order),
# so an isolated section elsewhere can no longer satisfy the audit.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  n2c=$(awk '/^### 2c\./{print NR; exit}' "$f")
  n2d=$(awk '/^### 2d\. Working-language canonicalization gate/{print NR; exit}' "$f")
  n3=$(awk '/^### 3\. Produce the upgrade plan/{print NR; exit}' "$f")
  n4c=$(awk '/^### 4c\./{print NR; exit}' "$f")
  n4cb=$(awk '/^#### 4c-bis\./{print NR; exit}' "$f")
  n4d=$(awk '/^### 4d\. Write the version marker/{print NR; exit}' "$f")

  # the working-language gate is a main-flow branch sitting between the
  # triage (2c) and the plan (3), and it blocks the "no decision pending" and
  # plan-finalization conclusions.
  if [ -z "$n2d" ] || [ -z "$n2c" ] || [ -z "$n3" ] || [ "$n2d" -le "$n2c" ] || [ "$n2d" -ge "$n3" ]; then
    fail "working-language gate is not a main-flow step between 2c and 3: $f"
  else
    gate=$(awk -v s="$n2d" -v e="$n3" 'NR>=s && NR<e' "$f")
    for a in 'MANDATORY main-flow branch' 'Presence of the file is the trigger' 'takes precedence' 'may **not** declare `USER_DECISION_REQUIRED = none`' 'may **not** present or finalize the step 3 plan'; do
      contains "$gate" "$a" || fail "working-language gate missing reachability anchor '$a': $f"
    done
  fi

  # an INDEPENDENT filesystem postcondition exists after the ownership
  # verification, and the old alias cannot survive into UPDATED.
  if [ -z "$n4cb" ] || [ -z "$n4c" ] || [ -z "$n4d" ] || [ "$n4cb" -le "$n4c" ] || [ "$n4cb" -ge "$n4d" ]; then
    fail "disk-state convergence gate missing or not between 4c and 4d: $f"
  else
    disk=$(awk -v s="$n4cb" -v e="$n4d" 'NR>s && NR<e' "$f")
    for a in 'inspects the actual filesystem' 'Reasoning state is **not** evidence' 'project-language.md still present' 'Canonical authority check'; do
      contains "$disk" "$a" || fail "disk-state gate missing convergence anchor '$a': $f"
    done
  fi

  # the marker write is downstream of alias convergence. The generic marker-order check already proves
  # marker-LAST generically; this only connects it to the alias gate.
  if [ -n "$n4d" ]; then
    awk -v s="$n4d" 'NR>s && index($0,"surviving `project-language.md` that has not converged"){found=1} END{exit !found}' "$f" \
      || fail "marker step not gated on working-language convergence: $f"
  fi

done
# upgrade-procedure separation (bootstrap architecture): the deployed
# /sdd-upgrade command — project shim and global bootstrap — carries NO upgrade
# business logic; the full canonical procedure lives in reference/upgrade/,
# outside reference/commands/, and is read at run time from the current
# reference, so stale project-local upgrade logic is structurally impossible.
for f in core/commands/sdd-upgrade.md skills/*/reference/commands/sdd-upgrade.md global-commands/sdd-upgrade.md; do
  [ -f "$f" ] || { fail "missing bootstrap shim: $f"; continue; }
  for a in 'no upgrade business logic' 'upgrade/sdd-upgrade-procedure.md' 'as instructions' 'CURRENT_REFERENCE_PROCEDURE_ACTIVE' 'never persisted to disk' 'No hybrid execution' 'Idempotence'; do
    grep -qF -- "$a" "$f" || fail "bootstrap shim missing contract anchor '$a': $f"
  done
  for a in 'USER_DECISION_REQUIRED' 'REPLACE_FROM_FRAMEWORK' 'STRUCTURAL_LEGACY_MIGRATION' '.sdd-version' '### 2c' '### 4c' 'Layer-3 canonical working-language alias' 'constitution' 'migration map' 'Do you confirm'; do
    grep -qF -- "$a" "$f" && fail "bootstrap shim carries upgrade business logic ('$a'): $f"
  done
done
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || { fail "missing canonical upgrade procedure: $f"; continue; }
  for a in 'canonical upgrade procedure' 'never deployed into a project' 'CURRENT_REFERENCE_PROCEDURE_ACTIVE' 'No hybrid execution' 'stable bootstrap shim' 'equals the reference **shim** exactly'; do
    grep -qF -- "$a" "$f" || fail "canonical procedure missing bootstrap-contract anchor '$a': $f"
  done
done
# global bootstrap: byte-parity with the project shim, and the install /
# global-upgrade scripts manage ~/.claude/commands/sdd-upgrade.md (safety
# policy: missing→install, identical→no-op, known toolkit version→update,
# divergent→never overwritten silently). The one-time project migration path
# ships with its exact-hash ownership manifest.
cmp -s core/commands/sdd-upgrade.md global-commands/sdd-upgrade.md \
  || fail "global bootstrap differs from the project shim"
for s in install.sh upgrade-global.sh; do
  grep -qF -- 'global-commands/sdd-upgrade.md' "$s" || fail "$s does not manage the global bootstrap source"
  grep -qF -- '.claude/commands' "$s" || fail "$s does not target ~/.claude/commands"
done
for s in install.ps1 upgrade-global.ps1; do
  grep -qF -- 'global-commands\sdd-upgrade.md' "$s" || fail "$s does not manage the global bootstrap source"
  grep -qF -- '.claude\commands' "$s" || fail "$s does not target ~/.claude/commands"
done
[ -s scripts/sdd-upgrade.known-hashes ] || fail "known-hashes ownership manifest missing or empty"
grep -qF -- 'sdd-upgrade.known-hashes' upgrade-global.sh || fail "upgrade-global.sh does not use the ownership manifest"
grep -qF -- 'sdd-upgrade.known-hashes' upgrade-global.ps1 || fail "upgrade-global.ps1 does not use the ownership manifest"
grep -qF -- '--project' upgrade-global.sh || fail "upgrade-global.sh missing the one-time --project migration"
grep -qF -- 'ProjectPath' upgrade-global.ps1 || fail "upgrade-global.ps1 missing the one-time -ProjectPath migration"
# Bootstrap behavioral fixture — presence anchors proved insufficient (a stale toolkit-owned
# bootstrap silently collapsed into the preserve case): the four-case
# classification of install.sh is proven on a REAL disposable fixture, in a
# temporary HOME — the user's ~/.claude is never touched. All four scripts must
# classify ownership from the same canonical evidence (the shipped exact-hash
# manifest, plus exact git-object history) — never from filename or shape.
grep -qF -- 'sdd-upgrade.known-hashes' install.sh  || fail "install.sh does not use the ownership manifest"
grep -qF -- 'sdd-upgrade.known-hashes' install.ps1 || fail "install.ps1 does not use the ownership manifest"
# install.ps1 structural parity: the same four dispositions, same evidence
# (a live PowerShell fixture is out of scope for this bash audit).
grep -qF -- 'Test-MatchesManifest $gdst' install.ps1 || fail "install.ps1 bootstrap dispatch does not consult the manifest classifier"
grep -qF -- 'known stale toolkit bootstrap - updated' install.ps1 || fail "install.ps1 missing the stale-toolkit-owned auto-update disposition"
grep -qF -- 'kept (re-run with -Force to overwrite)' install.ps1 || fail "install.ps1 missing the custom-preserved disposition"
boot_fix_home=$(mktemp -d 2>/dev/null)
if [ -z "$boot_fix_home" ] || [ ! -d "$boot_fix_home" ]; then
  fail "bootstrap behavioral fixture: mktemp failed"
else
  boot_fix_dst="$boot_fix_home/.claude/commands/sdd-upgrade.md"
  # case 1 — missing → install the current bootstrap
  HOME="$boot_fix_home" bash install.sh >/dev/null 2>&1 || fail "install.sh failed in the disposable fixture"
  cmp -s global-commands/sdd-upgrade.md "$boot_fix_dst" || fail "install.sh: missing global bootstrap was not installed"
  # case 2 — byte-identical current → no-op (file still current after re-run)
  HOME="$boot_fix_home" bash install.sh >/dev/null 2>&1 || fail "install.sh re-run failed in the disposable fixture"
  cmp -s global-commands/sdd-upgrade.md "$boot_fix_dst" || fail "install.sh: current global bootstrap not current after re-run"
  # case 3 — known stale toolkit-owned → automatic update. The fixture is a real
  # historical toolkit version (manifest-proven); it needs git objects to
  # materialize, so without history this sub-case is skipped with a notice,
  # like the release-tag check.
  if git rev-parse --git-dir >/dev/null 2>&1 \
     && git show v1.17.0:core/commands/sdd-upgrade.md > "$boot_fix_dst" 2>/dev/null \
     && ! cmp -s global-commands/sdd-upgrade.md "$boot_fix_dst"; then
    HOME="$boot_fix_home" bash install.sh >/dev/null 2>&1 || fail "install.sh failed on the stale-bootstrap fixture"
    cmp -s global-commands/sdd-upgrade.md "$boot_fix_dst" || fail "install.sh: known stale toolkit-owned bootstrap was NOT auto-updated"
  else
    say "  · notice: git objects unavailable — stale-bootstrap behavioral sub-case skipped"
    cp global-commands/sdd-upgrade.md "$boot_fix_dst"
  fi
  # case 4 — custom/divergent/unverifiable → preserved byte-for-byte, no --force
  printf 'custom user bootstrap — not toolkit-owned\n' > "$boot_fix_dst"
  cp "$boot_fix_dst" "$boot_fix_home/custom.orig"
  HOME="$boot_fix_home" bash install.sh >/dev/null 2>&1 || fail "install.sh failed on the custom-bootstrap fixture"
  cmp -s "$boot_fix_home/custom.orig" "$boot_fix_dst" || fail "install.sh: custom bootstrap was overwritten without --force"
  rm -rf "$boot_fix_home"
fi
# the canonical procedure is runtime reference material only: no
# fresh-install deployment list may copy it into a project's .claude/.
for s in $SKILLS; do
  grep -qF -- 'sdd-upgrade-procedure' "skills/$s/SKILL.md" && fail "$s: SKILL.md deploys the upgrade procedure into the project"
done
# working-language framework default: the universal rule establishes
# English as the default project-facing SDD language, and the retired
# infer-from-user fallback is gone everywhere.
awk '/^## Working language/{f=1;next} /^## /{f=0} f && index($0,"The framework default project-facing SDD language is English"){found=1} END{exit !found}' core/rules/00-sdd-framework.md \
  || fail "00-sdd-framework does not establish the English SDD-language default"
c=$(grep -rlF -- 'language the user works in' core skills global-commands --include='*.md' 2>/dev/null | wc -l)
[ "$c" -eq 0 ] || fail "retired infer-from-user language fallback still present ($c file(s))"
# every installer explicitly resolves the SDD language before the
# Layer-3 proposal/records/rendering.
for s in $SKILLS; do
  grep -qF -- 'Which language should project-facing SDD artifacts and SDD analysis use?' "skills/$s/SKILL.md" \
    || fail "$s: SKILL.md missing the explicit SDD-language question"
  grep -qF -- 'Explicit SDD working-language resolution — mandatory before Phase 2' "skills/$s/SKILL.md" \
    || fail "$s: SKILL.md missing the mandatory pre-Phase-2 language-resolution step"
done
# English default never forces Layer 3; non-English is the only reason
# the canonical override file exists.
for s in $SKILLS; do
  grep -qF -- 'no `project-working-language.md` is created for that choice alone' "skills/$s/SKILL.md" \
    || fail "$s: SKILL.md missing the no-redundant-English-Layer-3 contract"
  grep -qF -- 'English — framework default' "skills/$s/SKILL.md" \
    || fail "$s: SKILL.md does not present English as the framework default"
done
# Spec HOW leakage: the canonical spec producers/templates must carry the
# implementation-cleanup ban and the observable-contract allowance, and the
# quality gate must document semantic leakage detection (not only legacy
# headings). Honest boundary (Known-Limits style): static anchors prove the
# contract ships; only an unbiased replay proves a runtime spec obeys it.
for spec_surface in core/commands/sdd-spec.md core/templates/spec.md core/agents/spec-writer.md core/commands/sdd-spec-check.md; do
  for a in 'implementation cleanup' 'observable contract detail'; do
    grep -qiF -- "$a" "$spec_surface" || fail "spec surface missing spec-HOW contract anchor '$a': $spec_surface"
  done
  grep -qiF -- 'observable behavior' "$spec_surface" || fail "spec surface missing the observable-behavior AC anchor: $spec_surface"
done
# the quality gate names each machine-recognizable implementation-only class
# and both redirection destinations:
for a in 'source paths' 'remove the CSS override' 'delete the obsolete selector' 'no obsolete rule remains' 'plan.md' 'notes.md' 'must NOT be flagged'; do
  grep -qF -- "$a" core/commands/sdd-spec-check.md || fail "sdd-spec-check missing HOW-leakage class/destination anchor '$a'"
done
# Synthetic behavior fixture: the bounded leakage classes the gate documents are
# mirrored here as one regex; every implementation-only fixture line must be
# caught and no approved observable-contract line may be flagged.
SPEC_HOW_LEAK_RE='(remove|delete)[^.]*(override|selector|rule)|modify src/|\.(ts|css|scss|php|java)([^a-z]|$)|internal [a-z]+ api|no obsolete'
spec_how_bad='remove the css height override
delete the obsolete selector .old-button
modify src/app/button/button.component.ts
use the internal layoutengine api as the implementation mechanism
no obsolete css rule remains in the stylesheet'
spec_how_good='the button renders at the approved medium design-system size
the visible download icon is added to the button
the layout does not overflow at 768px
the accessible name remains unchanged and focus stays visible'
while IFS= read -r l; do
  [ -n "$l" ] || continue
  [[ "${l,,}" =~ $SPEC_HOW_LEAK_RE ]] || fail "spec-HOW fixture: implementation-only line not caught by the documented classes: $l"
done <<EOF_SPECHOWB
$spec_how_bad
EOF_SPECHOWB
while IFS= read -r l; do
  [ -n "$l" ] || continue
  [[ "${l,,}" =~ $SPEC_HOW_LEAK_RE ]] && fail "spec-HOW fixture: approved observable-contract line falsely flagged: $l"
done <<EOF_SPECHOWG
$spec_how_good
EOF_SPECHOWG
# One-time pre-v1.18 legacy-language migration REACHABILITY: the gate is a
# main-flow step between the 2d alias gate and the step 3 plan, carries the
# trigger/evidence/decision contract, and the marker step is connected to it —
# an isolated prose section elsewhere cannot satisfy this guard.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  ll_n2d=$(awk '/^### 2d\. Working-language canonicalization gate/{print NR; exit}' "$f")
  ll_n2e=$(awk '/^### 2e\. One-time legacy working-language migration gate/{print NR; exit}' "$f")
  ll_n3=$(awk '/^### 3\. Produce the upgrade plan/{print NR; exit}' "$f")
  ll_n4d=$(awk '/^### 4d\. Write the version marker/{print NR; exit}' "$f")
  if [ -z "$ll_n2e" ] || [ -z "$ll_n2d" ] || [ -z "$ll_n3" ] || [ "$ll_n2e" -le "$ll_n2d" ] || [ "$ll_n2e" -ge "$ll_n3" ]; then
    fail "legacy-language migration gate is not a main-flow step between 2d and 3: $f"
  else
    legacy_lang_gate=$(awk -v s="$ll_n2e" -v e="$ll_n3" 'NR>=s && NR<e' "$f")
    for a in 'ALL conditions must hold' 'older than `1.18.0`' 'ACTIVE project-facing SDD artifacts exist' '_archive' 'evidence for the question, never authority to choose' 'may **not** proceed to the step 4d marker write' 'at best ⚠️ UPDATED PARTIALLY' 'no** `project-working-language.md` is created'; do
      contains "$legacy_lang_gate" "$a" || fail "legacy-language migration gate missing anchor '$a': $f"
    done
  fi
  if [ -n "$ll_n4d" ]; then
    awk -v s="$ll_n4d" 'NR>s && index($0,"pending step 2e legacy-language decision"){found=1} END{exit !found}' "$f" \
      || fail "marker step not gated on the legacy-language migration: $f"
  fi
done
# Minimal working-language Layer 3: neither the fresh-install renderer nor
# the migration renderer may inject unrelated policy (Git, branches, source
# comments, README, technical docs, terminology) into project-working-language.md.
for f in core/upgrade/sdd-upgrade-procedure.md skills/*/reference/upgrade/sdd-upgrade-procedure.md; do
  [ -f "$f" ] || continue
  for a in 'All other language domains remain governed by their existing owners' 'never adds any other policy domain' 'no Git, branch or commit clause'; do
    grep -qF -- "$a" "$f" || fail "migration renderer missing minimal-Layer-3 anchor '$a': $f"
  done
  grep -qiE 'project-working-language[^.]*(also governs|extends to|additionally covers)' "$f" \
    && fail "working-language file scope expanded beyond SDD communication: $f"
done
for s in $SKILLS; do
  grep -qF -- 'one atomic claim' "skills/$s/SKILL.md" || fail "$s: SKILL.md missing the one-atomic-claim language anchor"
  grep -qF -- 'renderer transcribes only that approved content' "skills/$s/SKILL.md" || fail "$s: SKILL.md missing the transcription-only language-renderer anchor"
  grep -qiE 'project-working-language[^.]*(also governs|extends to|additionally covers)' "skills/$s/SKILL.md" \
    && fail "$s: SKILL.md expands the working-language file beyond SDD communication"
done
# Public vocabulary: the tracked tree must not contain real internal
# validation names. The tokens are hex-encoded so this guard can never match its
# own definition; matching is boundary-guarded and case-insensitive.
PUBLIC_VOCAB_HEX='67726466 70757367 706c616e6e696e6720757367 63646d 637475 636d61 737475 617468656e61 70726f74656361'
for pv_hex in $PUBLIC_VOCAB_HEX; do
  pv_tok=$(printf '%b' "$(printf '%s' "$pv_hex" | sed 's/../\\x&/g')")
  public_vocab_hits=$(grep -rilE "(^|[^[:alpha:]])${pv_tok}([^[:alpha:]]|\$)" core skills global-agents global-commands scripts README.md INSTALL.md CHANGELOG.md LICENSE VERSION install.sh install.ps1 upgrade-global.sh upgrade-global.ps1 2>/dev/null)
  [ -z "$public_vocab_hits" ] || fail "internal validation name (encoded $pv_hex) present in the public tree: $(printf '%s' "$public_vocab_hits" | tr '\n' ' ')"
done
[ $err -eq $before ] && ok "behavioral contracts hold (language owner/default + alias + legacy migration gates, source isolation, commit producers, upgrade autonomy + marker order + convergence, bootstrap parity + procedure separation, install language resolution, spec/plan boundary + HOW-leakage, minimal language Layer 3, public vocabulary)"

# =====================================================================
say "== 6. Content equality of shared files (anti-drift) =="
before=$err
# 6a. The core/ masters must be byte-identical in the 6 skills.
#     Legitimate exclusion: test-generator.md (adapted per stack).
mcount=0
for cf in core/commands/*.md core/agents/*.md core/templates/*.md core/rules/*.md core/upgrade/*.md; do
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
#     12-quality-gates, 50-api-contracts; 62-migration-guard diverges between the symfony pair
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
  contains "$anat" "**$fld**" \
    || fail "00-sdd-framework: tasks anatomy missing phase-block field: $fld"
done <<EOF_PF
$pf
EOF_PF
af=$(printf '%s\n' "$anat" | sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' | sort -u)
while IFS= read -r fld; do
  [ -n "$fld" ] || continue
  has_line "$pf" "$fld" \
    || fail "templates/tasks.md lost phase-block field still declared by the anatomy: $fld"
done <<EOF_AF
$af
EOF_AF
check_shared "angular" "sdd-symfony-angular sdd-angular-node sdd-java-angular" \
  commands/angular-component.md commands/angular-service.md commands/angular-test.md \
  rules/40-angular-conventions.md
check_shared "symfony" "sdd-php-symfony sdd-symfony-angular" \
  commands/symfony-entity.md commands/symfony-service.md commands/symfony-controller.md commands/symfony-test.md \
  rules/30-doctrine-conventions.md
check_shared "java" "sdd-java-backend sdd-java-angular" \
  commands/java-entity.md commands/java-service.md commands/java-controller.md commands/java-test.md \
  rules/30-jpa-conventions.md rules/62-migration-guard.md
[ $err -eq $before ] && ok "$mcount core masters + angular/symfony/java groups identical (hash)"

# =====================================================================
echo ""
if [ $err -eq 0 ]; then echo "✅ AUDIT OK — no inconsistency detected."; else echo "❌ AUDIT: $err problem(s) detected."; fi
exit $err
