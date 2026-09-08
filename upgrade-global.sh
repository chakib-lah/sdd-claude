#!/usr/bin/env bash
# SDD Claude — global ~/.claude upgrade (Linux / macOS / WSL2)
# Syncs the skill symlinks and refreshes the global agent copies after the
# toolkit evolves. Safe by default: a stale, unmodified agent is updated;
# a customized (or translated) agent is kept and reported, with a prompt.
#
# Usage: ./upgrade-global.sh [--force] [--keep-custom] [--project <path>]
#   --force            overwrite customized agents/bootstrap without prompting
#   --keep-custom      keep customized agents/bootstrap without prompting
#   --project <path>   one-time migration of ONE project's .claude/commands/
#                      sdd-upgrade.md to the current stable shim (only when the
#                      existing file is a verified historical toolkit version)
set -euo pipefail
shopt -s nullglob

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
COMMANDS_DST="$HOME/.claude/commands"

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

FORCE=0; KEEP=0; PROJECT=""
expect_project=0
for arg in "$@"; do
  if [ "$expect_project" = 1 ]; then PROJECT="$arg"; expect_project=0; continue; fi
  case "$arg" in
    --force) FORCE=1 ;;
    --keep-custom) KEEP=1 ;;
    --project) expect_project=1 ;;
    --project=*) PROJECT="${arg#--project=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done
[ "$expect_project" = 0 ] || { echo "--project requires a path" >&2; exit 1; }

# Portable SHA-256 (manifest proof works without git history, e.g. ZIP install).
sha256f() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum < "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 < "$1" | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r < "$1" | cut -d' ' -f1
  else return 1; fi
}

# Without a tty we cannot prompt: default to keeping customized agents.
if [ "$FORCE" = 0 ] && [ "$KEEP" = 0 ] && ! [ -r /dev/tty ]; then
  KEEP=1
  echo "non-interactive session: customized agents will be kept (use --force to overwrite)" >&2
fi

VERSION="?"
[ -f "$TOOLKIT_DIR/VERSION" ] && VERSION="$(cat "$TOOLKIT_DIR/VERSION")"

# Stale-vs-customized detection needs the toolkit's full git history.
HAVE_HISTORY=1
if ! git -C "$TOOLKIT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  HAVE_HISTORY=0
elif [ "$(git -C "$TOOLKIT_DIR" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  HAVE_HISTORY=0
fi

echo "════════════════════════════════════════════"
echo " SDD Claude — global upgrade (toolkit v$VERSION)"
echo " Source: $TOOLKIT_DIR"
echo "════════════════════════════════════════════"
[ "$HAVE_HISTORY" = 1 ] || echo "⚠ no git history available (ZIP download or shallow clone) — divergent agents cannot be classified stale vs customized" >&2

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

echo "→ Skills (symlinks):"
found_skill=0
for src in "$TOOLKIT_DIR"/skills/sdd-*/; do
  found_skill=1
  src="${src%/}"
  s="$(basename "$src")"
  dst="$SKILLS_DST/$s"
  if [ -L "$dst" ] && [ "$(cd -P "$dst" 2>/dev/null && pwd)" = "$(cd -P "$src" && pwd)" ]; then
    echo "  ✓ $s (current)"
  elif [ -L "$dst" ]; then
    rm "$dst"; ln -s "$src" "$dst"   # a link is not user data — replace silently
    echo "  ~ $s (repaired → symlink)"
  elif [ -e "$dst" ]; then
    bak="$dst.bak-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$dst" "$bak"   # real directory/file: user data — back up, never delete
    echo "  ⚠ existing $s was a real directory — backed up to $bak"
    ln -s "$src" "$dst"
    echo "  ~ $s (repaired → symlink)"
  else
    ln -s "$src" "$dst"
    echo "  + $s (added)"
  fi
done
[ "$found_skill" = 1 ] || { echo "  ✗ no skills found under $TOOLKIT_DIR/skills/ — aborting" >&2; exit 1; }

# Returns 0 if the installed copy matches ANY committed version of the file
# (i.e. stale but unmodified). Compares git object IDs — no content pipeline.
matches_history() {
  local relfile="$1" installed="$2" oid rev
  [ "$HAVE_HISTORY" = 1 ] || return 1
  oid="$(git -C "$TOOLKIT_DIR" hash-object -- "$installed")" || return 1
  for rev in $(git -C "$TOOLKIT_DIR" rev-list HEAD -- "$relfile"); do
    if [ "$(git -C "$TOOLKIT_DIR" rev-parse "$rev:$relfile" 2>/dev/null)" = "$oid" ]; then
      return 0
    fi
  done
  return 1
}

echo "→ Global agents (copies):"
UPDATED=0; KEPT=0; found_agent=0
for src in "$TOOLKIT_DIR"/global-agents/*.md; do
  found_agent=1
  name="$(basename "$src")"
  dst="$AGENTS_DST/$name"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"; echo "  + $name (added)"
  elif cmp -s "$src" "$dst"; then
    echo "  ✓ $name (current)"
  elif matches_history "global-agents/$name" "$dst"; then
    cp "$src" "$dst"; echo "  ↑ $name (stale → updated)"; UPDATED=$((UPDATED+1))
  else
    # Customized/translated copy — or unverifiable (no history). Never overwrite silently.
    if [ "$HAVE_HISTORY" = 1 ]; then
      reason="differs from every toolkit version (customized or translated copy)"
    else
      reason="differs from the toolkit version (cannot verify: no git history)"
    fi
    if [ "$FORCE" = 1 ]; then
      cp "$src" "$dst"; echo "  ↑ $name (divergent → overwritten, --force)"; UPDATED=$((UPDATED+1))
    elif [ "$KEEP" = 1 ]; then
      echo "  ⚠ $name ($reason — kept)"; KEPT=$((KEPT+1))
    else
      echo "  ⚠ $name $reason." >&2
      printf "    Overwrite with the toolkit version? [y/N] " >&2
      read -r answer </dev/tty || answer="n"
      if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        cp "$src" "$dst"; echo "  ↑ $name (overwritten)"; UPDATED=$((UPDATED+1))
      else
        echo "  ⚠ $name (kept)"; KEPT=$((KEPT+1))
      fi
    fi
  fi
done
[ "$found_agent" = 1 ] || { echo "  ✗ no agents found under $TOOLKIT_DIR/global-agents/ — aborting" >&2; exit 1; }
echo "  (files in $AGENTS_DST not shipped by the toolkit are never touched)"

# True if the file's exact SHA-256 appears in the shipped manifest of known
# toolkit-owned sdd-upgrade.md versions (works without git history).
matches_manifest() {
  local file="$1" h
  [ -f "$TOOLKIT_DIR/scripts/sdd-upgrade.known-hashes" ] || return 1
  h="$(sha256f "$file")" || return 1
  grep -q "^$h " "$TOOLKIT_DIR/scripts/sdd-upgrade.known-hashes"
}

echo "→ Global /sdd-upgrade bootstrap (copy):"
mkdir -p "$COMMANDS_DST"
gsrc="$TOOLKIT_DIR/global-commands/sdd-upgrade.md"
gdst="$COMMANDS_DST/sdd-upgrade.md"
if [ ! -f "$gsrc" ]; then
  echo "  ✗ toolkit bootstrap missing: $gsrc" >&2; exit 1
elif [ ! -f "$gdst" ]; then
  cp "$gsrc" "$gdst"; echo "  + sdd-upgrade.md (added)"
elif cmp -s "$gsrc" "$gdst"; then
  echo "  ✓ sdd-upgrade.md (current)"
elif matches_manifest "$gdst" || matches_history "global-commands/sdd-upgrade.md" "$gdst"; then
  cp "$gsrc" "$gdst"; echo "  ↑ sdd-upgrade.md (stale toolkit bootstrap → updated)"
elif [ "$FORCE" = 1 ]; then
  cp "$gsrc" "$gdst"; echo "  ↑ sdd-upgrade.md (divergent → overwritten, --force)"
elif [ "$KEEP" = 1 ]; then
  echo "  ⚠ sdd-upgrade.md differs from every known toolkit version — kept (re-run with --force to overwrite)"
else
  echo "  ⚠ ~/.claude/commands/sdd-upgrade.md differs from every known toolkit version." >&2
  printf "    Overwrite with the toolkit bootstrap? [y/N] " >&2
  read -r answer </dev/tty || answer="n"
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    cp "$gsrc" "$gdst"; echo "  ↑ sdd-upgrade.md (overwritten)"
  else
    echo "  ⚠ sdd-upgrade.md (kept)"
  fi
fi

# --project <path>: ONE-TIME migration of a single project's local updater.
# The ONLY project mutation performed: <project>/.claude/commands/sdd-upgrade.md
# is replaced by the current stable shim IFF the existing file is proven
# toolkit-owned (exact SHA-256 in the shipped manifest, or exact git object
# match against toolkit history when available). Divergent/unverifiable files
# are preserved and reported — ownership is never guessed, and no other
# project file is touched (run /sdd-upgrade inside the project for the rest).
if [ -n "$PROJECT" ]; then
  echo "→ Project one-time /sdd-upgrade migration: $PROJECT"
  pfile="$PROJECT/.claude/commands/sdd-upgrade.md"
  shim="$TOOLKIT_DIR/core/commands/sdd-upgrade.md"
  if [ ! -d "$PROJECT/.claude" ]; then
    echo "  ✗ $PROJECT/.claude not found — is this an SDD project?" >&2; exit 1
  elif [ ! -f "$pfile" ]; then
    echo "  · no local /sdd-upgrade command — nothing to migrate"
  elif cmp -s "$shim" "$pfile"; then
    echo "  ✓ already the current stable shim — nothing to do"
  elif matches_manifest "$pfile" \
       || matches_history "core/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-php-backend/reference/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-php-symfony/reference/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-symfony-angular/reference/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-angular-node/reference/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-java-backend/reference/commands/sdd-upgrade.md" "$pfile" \
       || matches_history "skills/sdd-java-angular/reference/commands/sdd-upgrade.md" "$pfile"; then
    cp "$shim" "$pfile"
    echo "  ↑ known historical toolkit updater → replaced with the current stable shim"
    echo "    Next step: run /sdd-upgrade inside the project (it now loads the current procedure)"
  else
    echo "  ⚠ $pfile differs from every known toolkit-owned version (customized, translated, or unverifiable)." >&2
    echo "    Automatic migration refused — ownership is never guessed. Review the file manually," >&2
    echo "    or run /sdd-upgrade inside the project so its own triage handles it." >&2
  fi
fi

echo ""
echo "✅ Global upgrade complete (toolkit v$VERSION)."
[ "$UPDATED" -gt 0 ] && echo "   Updated agents: $UPDATED"
[ "$KEPT" -gt 0 ] && echo "   Divergent agents kept: $KEPT (re-run with --force to overwrite)"
echo "   Note: projects are upgraded separately — run /sdd-upgrade inside each project."
