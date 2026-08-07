#!/usr/bin/env bash
# SDD Claude — global ~/.claude upgrade (Linux / macOS / WSL2)
# Syncs the skill symlinks and refreshes the global agent copies after the
# toolkit evolves. Safe by default: a stale, unmodified agent is updated;
# a customized (or translated) agent is kept and reported, with a prompt.
#
# Usage: ./upgrade-global.sh [--force] [--keep-custom]
#   --force        overwrite customized agents without prompting
#   --keep-custom  keep customized agents without prompting
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"

FORCE=0; KEEP=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --keep-custom) KEEP=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

VERSION="?"
[ -f "$TOOLKIT_DIR/VERSION" ] && VERSION="$(cat "$TOOLKIT_DIR/VERSION")"

echo "════════════════════════════════════════════"
echo " SDD Claude — global upgrade (toolkit v$VERSION)"
echo " Source: $TOOLKIT_DIR"
echo "════════════════════════════════════════════"

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

echo "→ Skills (symlinks):"
for src in "$TOOLKIT_DIR"/skills/sdd-*/; do
  s="$(basename "$src")"
  src="${src%/}"
  dst="$SKILLS_DST/$s"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ✓ $s (current)"
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    rm -rf "$dst"; ln -s "$src" "$dst"
    echo "  ~ $s (repaired → symlink)"
  else
    ln -s "$src" "$dst"
    echo "  + $s (added)"
  fi
done

# Returns 0 if the installed copy matches ANY committed version of the file
# (i.e. stale but unmodified), 1 otherwise (customized/translated).
matches_history() {
  local relfile="$1" installed="$2" rev
  ( cd "$TOOLKIT_DIR" &&
    for rev in $(git rev-list HEAD -- "$relfile" 2>/dev/null); do
      if git show "$rev:$relfile" 2>/dev/null | cmp -s - "$installed"; then
        return 0
      fi
    done
    return 1 )
}

echo "→ Global agents (copies):"
UPDATED=0; KEPT=0
for src in "$TOOLKIT_DIR"/global-agents/*.md; do
  name="$(basename "$src")"
  dst="$AGENTS_DST/$name"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"; echo "  + $name (added)"
  elif cmp -s "$src" "$dst"; then
    echo "  ✓ $name (current)"
  elif matches_history "global-agents/$name" "$dst"; then
    cp "$src" "$dst"; echo "  ↑ $name (stale → updated)"; UPDATED=$((UPDATED+1))
  else
    # Customized or translated copy — never overwrite silently
    if [ "$FORCE" = 1 ]; then
      cp "$src" "$dst"; echo "  ↑ $name (customized → overwritten, --force)"; UPDATED=$((UPDATED+1))
    elif [ "$KEEP" = 1 ]; then
      echo "  ⚠ $name (customized — kept)"; KEPT=$((KEPT+1))
    else
      echo "  ⚠ $name differs from every toolkit version (customized or translated copy)."
      printf "    Overwrite with the toolkit version? [y/N] "
      read -r answer </dev/tty || answer="n"
      if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        cp "$src" "$dst"; echo "  ↑ $name (overwritten)"; UPDATED=$((UPDATED+1))
      else
        echo "  ⚠ $name (kept)"; KEPT=$((KEPT+1))
      fi
    fi
  fi
done
echo "  (files in $AGENTS_DST not shipped by the toolkit are never touched)"

echo ""
echo "✅ Global upgrade complete (toolkit v$VERSION)."
[ "$UPDATED" -gt 0 ] && echo "   Updated agents: $UPDATED"
[ "$KEPT" -gt 0 ] && echo "   Customized agents kept: $KEPT (re-run with --force to overwrite)"
echo "   Note: projects are upgraded separately — run /sdd-upgrade inside each project."
