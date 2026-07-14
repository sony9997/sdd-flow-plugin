#!/bin/sh
# Verify sdd-flow skills are installed and OpenCode-discoverable at DEST.
set -u
DEST="${SDD_INSTALL_DIR:-$HOME/.config/opencode/skills}"
rc=0
for s in sdd-flow sdd-gate sdd-progress; do
  f="$DEST/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "FAIL: $s missing at $f" >&2
    rc=1
    continue
  fi
  fm=$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$fm" != "$s" ]; then
    echo "FAIL: $s frontmatter name '$fm' != '$s'" >&2
    rc=1
    continue
  fi
  desc=$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//')
  if [ -z "$desc" ]; then
    echo "FAIL: $s description empty" >&2
    rc=1
    continue
  fi
  echo "PASS: $s"
done
exit "$rc"
