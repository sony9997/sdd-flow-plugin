#!/bin/sh
# Install sdd-flow skills into an OpenCode-scanned path (default ~/.claude/skills).
# Idempotent. Exits 0 if all skills installed, 1 if any skipped/validated-fail.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC="${SDD_SOURCE_DIR:-$ROOT/skills}"
DEST="${SDD_INSTALL_DIR:-$HOME/.claude/skills}"

[ -d "$SRC" ] || { echo "ERROR: source skills dir not found: $SRC" >&2; exit 1; }
mkdir -p "$DEST"

rc=0
count=0
for skill_dir in "$SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    echo "WARN: $name has no SKILL.md, skip" >&2
    rc=1
    continue
  fi
  fm_name=$(grep -m1 '^name:' "$skill_md" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$fm_name" != "$name" ]; then
    echo "ERROR: $name: frontmatter name '$fm_name' != dir name, skip (OpenCode requires match)" >&2
    rc=1
    continue
  fi
  mkdir -p "$DEST/$name"
  cp -R "$skill_dir/." "$DEST/$name/"
  echo "installed: $name -> $DEST/$name"
  count=$((count + 1))
done

echo "done: $count skill(s) -> $DEST"
echo "restart OpenCode (or open a new session) for skills to be discovered"
exit "$rc"
