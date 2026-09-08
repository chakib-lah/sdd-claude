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
COMMANDS_DST="$HOME/.claude/commands"
SKILLS="sdd-php-backend sdd-php-symfony sdd-symfony-angular sdd-angular-node sdd-java-backend sdd-java-angular"

# Portable SHA-256 (manifest proof works without git history, e.g. ZIP install).
# Same classifiers as upgrade-global.sh — the ownership source of truth is the
# shipped scripts/sdd-upgrade.known-hashes manifest plus exact git-object
# history matching; ownership is never guessed from filename or content shape.
sha256f() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum < "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 < "$1" | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r < "$1" | cut -d' ' -f1
  else return 1; fi
}
# True if the file's exact SHA-256 appears in the shipped manifest of known
# toolkit-owned sdd-upgrade.md versions (works without git history).
matches_manifest() {
  local file="$1" h
  [ -f "$TOOLKIT_DIR/scripts/sdd-upgrade.known-hashes" ] || return 1
  h="$(sha256f "$file")" || return 1
  grep -q "^$h " "$TOOLKIT_DIR/scripts/sdd-upgrade.known-hashes"
}
# Returns 0 if the installed copy matches ANY committed version of the file
# (i.e. stale but unmodified). Compares git object IDs — no content pipeline.
matches_history() {
  local relfile="$1" installed="$2" oid rev
  git -C "$TOOLKIT_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 1
  [ "$(git -C "$TOOLKIT_DIR" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] && return 1
  oid="$(git -C "$TOOLKIT_DIR" hash-object -- "$installed")" || return 1
  for rev in $(git -C "$TOOLKIT_DIR" rev-list HEAD -- "$relfile"); do
    if [ "$(git -C "$TOOLKIT_DIR" rev-parse "$rev:$relfile" 2>/dev/null)" = "$oid" ]; then
      return 0
    fi
  done
  return 1
}

echo "════════════════════════════════════════════"
echo " SDD Claude — installation"
echo " Source: $TOOLKIT_DIR"
echo "════════════════════════════════════════════"

mkdir -p "$SKILLS_DST" "$AGENTS_DST" "$COMMANDS_DST"

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

echo "→ Global /sdd-upgrade bootstrap (copy):"
gsrc="$TOOLKIT_DIR/global-commands/sdd-upgrade.md"
gdst="$COMMANDS_DST/sdd-upgrade.md"
if [ ! -f "$gdst" ]; then
  cp "$gsrc" "$gdst"; echo "  ✓ sdd-upgrade.md installed into $COMMANDS_DST"
elif cmp -s "$gsrc" "$gdst"; then
  echo "  ✓ sdd-upgrade.md (current)"
elif matches_manifest "$gdst" || matches_history "global-commands/sdd-upgrade.md" "$gdst"; then
  cp "$gsrc" "$gdst"; echo "  ↑ sdd-upgrade.md (known stale toolkit bootstrap → updated)"
elif [ "$FORCE" -eq 1 ]; then
  cp "$gsrc" "$gdst"; echo "  ⚠ sdd-upgrade.md overwritten (--force)"
else
  echo "  ⚠ existing ~/.claude/commands/sdd-upgrade.md differs from every known toolkit version — kept (re-run with --force to overwrite)"
fi

echo ""
echo "✅ Installation complete."
echo "   Skills: $(ls "$SKILLS_DST" | grep -c '^sdd-[a-z-]*$') installed"
echo "   Verify: ls ~/.claude/skills/ && ls ~/.claude/agents/"
echo ""
echo "   To update later: git pull in $TOOLKIT_DIR (the symlinks follow)"
