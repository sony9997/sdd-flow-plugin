#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DEST="$TMP/skills"
export SDD_INSTALL_DIR="$DEST"

fail() { echo "FAIL: $1" >&2; exit 1; }

# scenario 1: installed -> verify exits 0
sh "$ROOT/scripts/install-opencode.sh" >/dev/null 2>&1 || fail "install failed"
sh "$ROOT/scripts/verify-opencode.sh" >/dev/null 2>&1 || fail "verify should pass after install"

# scenario 2: remove one skill -> verify exits 1
rm -rf "$DEST/sdd-gate"
sh "$ROOT/scripts/verify-opencode.sh" >/tmp/oc_v.log 2>&1 && fail "verify should fail when skill missing"

echo "test_verify_opencode PASS"
