#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export SDD_INSTALL_DIR="$TMP/skills"

fail() { echo "FAIL: $1" >&2; exit 1; }

# scenario 1: three skills land + name matches dir
sh "$ROOT/scripts/install-opencode.sh" >/tmp/oc_install.log 2>&1 || fail "install exited non-zero on clean run"
for s in sdd-flow sdd-gate sdd-progress; do
  [ -f "$TMP/skills/$s/SKILL.md" ] || fail "missing $s/SKILL.md"
done

# scenario 2: idempotent rerun
sh "$ROOT/scripts/install-opencode.sh" >/dev/null 2>&1 || fail "rerun not idempotent"

# scenario 3: name mismatch in injected source -> skipped + non-zero exit
BAD="$TMP/badsrc/badname"
mkdir -p "$BAD"
printf -- '---\nname: wrong\ndescription: x\n---\nbody\n' > "$BAD/SKILL.md"
SDD_SOURCE_DIR="$TMP/badsrc" SDD_INSTALL_DIR="$TMP/baddest" \
  sh "$ROOT/scripts/install-opencode.sh" >/tmp/oc_bad.log 2>&1 && fail "bad name should exit non-zero"
[ -d "$TMP/baddest/wrong" ] && fail "mismatched skill should not be copied"
[ -d "$TMP/baddest/badname" ] && fail "mismatched skill dir should not be created"

echo "test_install_opencode PASS"
