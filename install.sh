#!/usr/bin/env bash
# SDD Claude installer — Linux / macOS / WSL2
# Links the 4 skills (symlink → auto-update via git pull) and copies the 8 global agents.
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
SKILLS="sdd-php-backend sdd-php-symfony sdd-symfony-angular sdd-angular-node"

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
  if [ -e "$dst" ] || [ -L "$dst" ]; then rm -rf "$dst"; fi
  ln -s "$src" "$dst"
  echo "  ✓ $s"
done

echo "→ Global agents (copy):"
cp "$TOOLKIT_DIR"/global-agents/*.md "$AGENTS_DST"/
echo "  ✓ $(ls "$TOOLKIT_DIR"/global-agents/*.md | wc -l) agents copied into $AGENTS_DST"

echo ""
echo "✅ Installation complete."
echo "   Skills: $(ls "$SKILLS_DST" | grep -c sdd) installed"
echo "   Verify: ls ~/.claude/skills/ && ls ~/.claude/agents/"
echo ""
echo "   To update later: git pull in $TOOLKIT_DIR (the symlinks follow)"
