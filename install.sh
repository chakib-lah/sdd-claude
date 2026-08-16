#!/usr/bin/env bash
# SDD Claude installer — Linux / macOS / WSL2
# Links the 6 skills (symlink → auto-update via git pull) and copies the 9 global agents.
# Never destroys user data: a real directory found at a skill path is backed up,
# a divergent global agent is kept and reported (--force to overwrite, mirroring
# upgrade-global.sh). Symlinks point at the toolkit and are replaced silently.
set -euo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
SKILLS="sdd-php-backend sdd-php-symfony sdd-symfony-angular sdd-angular-node sdd-java-backend sdd-java-angular"

echo "════════════════════════════════════════════"
echo " SDD Claude — installation"
echo " Source: $TOOLKIT_DIR"
echo "════════════════════════════════════════════"

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

echo "→ Skills (symlink):"
for s in $SKILLS; do
  src="$TOOLKIT_DIR/skills/$s"
  dst="$SKILLS_DST/$s"
  [ -d "$src" ] || { echo "  ✗ not found: $src"; exit 1; }
  if [ -L "$dst" ]; then
    rm "$dst"          # symlink → toolkit: not user data, normal re-run, replace silently
  elif [ -e "$dst" ]; then
    bak="$dst.bak-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$dst" "$bak"   # real directory/file: user data — back up, never delete
    echo "  ⚠ existing $s was a real directory — backed up to $bak"
  fi
  ln -s "$src" "$dst"
  echo "  ✓ $s"
done

echo "→ Global agents (copy):"
copied=0; kept=0
for f in "$TOOLKIT_DIR"/global-agents/*.md; do
  a=$(basename "$f")
  dst="$AGENTS_DST/$a"
  if [ ! -f "$dst" ]; then
    cp "$f" "$dst"; copied=$((copied+1))
  elif cmp -s "$f" "$dst"; then
    :   # byte-identical to the toolkit version: nothing to do
  elif [ "$FORCE" -eq 1 ]; then
    cp "$f" "$dst"; copied=$((copied+1))
    echo "  ⚠ overwritten (--force): $a"
  else
    kept=$((kept+1))
    echo "  · kept (differs from toolkit): $a"
  fi
done
echo "  ✓ $copied agent(s) copied into $AGENTS_DST"
if [ "$kept" -gt 0 ]; then
  echo "  ⚠ $kept divergent agent(s) kept — re-run with --force to overwrite"
fi

echo ""
echo "✅ Installation complete."
echo "   Skills: $(ls "$SKILLS_DST" | grep -c '^sdd-[a-z-]*$') installed"
echo "   Verify: ls ~/.claude/skills/ && ls ~/.claude/agents/"
echo ""
echo "   To update later: git pull in $TOOLKIT_DIR (the symlinks follow)"
