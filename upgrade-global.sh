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
shopt -s nullglob

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"

usage() {
  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

FORCE=0; KEEP=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --keep-custom) KEEP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

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

echo ""
echo "✅ Global upgrade complete (toolkit v$VERSION)."
[ "$UPDATED" -gt 0 ] && echo "   Updated agents: $UPDATED"
[ "$KEPT" -gt 0 ] && echo "   Divergent agents kept: $KEPT (re-run with --force to overwrite)"
echo "   Note: projects are upgraded separately — run /sdd-upgrade inside each project."
