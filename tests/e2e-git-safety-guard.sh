#!/bin/bash
# E2E tests for git-safety-guard
# Simulates Claude Code hook invocations and verifies end-to-end behavior.
set -e

PASS=0
FAIL=0
HOOK_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
GUARD="$HOOK_DIR/git-guard.sh"

log_pass() { PASS=$((PASS + 1)); echo "  ✅ $1"; }
log_fail() { FAIL=$((FAIL + 1)); echo "  ❌ $1"; }

echo "=== Git Safety Guard E2E Tests ==="
echo ""

# ── git-guard.sh tests ──
echo "## git-guard.sh"

# Helper: test guard with given JSON input, expect exit code
test_guard() {
  local name="$1" expected="$2" json="$3"
  local actual=0
  echo "$json" | "$GUARD" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    log_pass "$name (exit $expected)"
  else
    log_fail "$name (expected exit $expected, got $actual)"
  fi
}

test_guard "block 'git merge main'"         2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"}}'
test_guard "block 'git merge master'"       2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge master"}}'
test_guard "block 'git merge origin/main'"  2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge origin/main"}}'
test_guard "block 'git merge origin/master'" 2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge origin/master"}}'
test_guard "block 'rtk git merge main'"     2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git merge main"}}'
test_guard "allow 'git merge feature/bar'"  0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge feature/bar"}}'
test_guard "allow 'git merge develop'"      0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge develop"}}'
test_guard "block 'git push'"               2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push"}}'
test_guard "block 'git push origin main'"   2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
test_guard "block 'rtk git push'"           2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git push"}}'
test_guard "block 'rtk git push --force'"   2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git push --force"}}'
test_guard "hint 'git commit -m fix' (exit 0)" 0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m fix: bug"}}'
test_guard "hint 'rtk git commit' (exit 0)" 0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git commit -m feat: thing"}}'
test_guard "passthrough 'ls'"               0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
test_guard "passthrough 'npm test'"         0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test"}}'
test_guard "passthrough 'echo hello'"       0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hello"}}'
test_guard "empty command"                  0 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":""}}'
test_guard "malformed JSON"                 0 'not valid json {{{'

echo ""

# ── stderr message content tests ──
echo "## stderr messages"

test_stderr_contains() {
  local name="$1" expected="$2" json="$3"
  local stderr
  stderr=$(echo "$json" | "$GUARD" 2>&1 >/dev/null) || true
  if echo "$stderr" | grep -qF "$expected"; then
    log_pass "$name"
  else
    log_fail "$name (expected stderr to contain '$expected', got: ${stderr:0:100})"
  fi
}

test_stderr_contains "merge block message"   "禁止合并到主干分支" '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"}}'
test_stderr_contains "push block message"    "推送需用户确认"     '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push"}}'
test_stderr_contains "commit hint message"   "conventional commit" '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m wip"}}'
test_stderr_contains "sdd-flow-git-block tag in merge" "sdd-flow-git-block" '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"}}'
test_stderr_contains "sdd-flow-git-block tag in push"  "sdd-flow-git-block" '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push"}}'
test_stderr_contains "sdd-flow-git-hint tag" "sdd-flow-git-hint"  '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m wip"}}'

echo ""

# ── sdd-hooks.json validation ──
echo "## sdd-hooks.json structure"

test_json_key() {
  local name="$1" hook_type="$2" expected="$3"
  local count
  count=$(python3 -c "import json; d=json.load(open('$HOOK_DIR/sdd-hooks.json')); print(len(d['hooks'].get('$hook_type',[])))")
  if [ "$count" -eq "$expected" ]; then
    log_pass "$name ($expected hook(s))"
  else
    log_fail "$name (expected $expected, got $count)"
  fi
}

test_json_key "UserPromptSubmit hooks" "UserPromptSubmit" 1
test_json_key "PreToolUse hooks"       "PreToolUse"       2
test_json_key "Stop hooks"             "Stop"             1

# Verify UserPromptSubmit has 2 commands (original reminder + branch check)
count=$(python3 -c "
import json
d=json.load(open('$HOOK_DIR/sdd-hooks.json'))
ups = d['hooks']['UserPromptSubmit'][0]['hooks']
print(len(ups))
")
if [ "$count" -eq 2 ]; then
  log_pass "UserPromptSubmit commands count (2)"
else
  log_fail "UserPromptSubmit commands count (expected 2, got $count)"
fi

# Verify PreToolUse has both Edit|Write matcher AND Bash matcher
pt_matchers=$(python3 -c "
import json
d=json.load(open('$HOOK_DIR/sdd-hooks.json'))
print([h['matcher'] for h in d['hooks']['PreToolUse']])
")
if echo "$pt_matchers" | grep -q "Edit" && echo "$pt_matchers" | grep -q "Bash"; then
  log_pass "PreToolUse matchers (Edit|Write + Bash)"
else
  log_fail "PreToolUse matchers (missing Edit|Write or Bash in: $pt_matchers)"
fi

echo ""

# ── Stop hook simulation ──
echo "## Stop hook"

# Extract and test the Stop hook command
STOP_CMD=$(python3 -c "
import json
d=json.load(open('$HOOK_DIR/sdd-hooks.json'))
print(d['hooks']['Stop'][0]['hooks'][0]['command'])
")

# Helper: run STOP_CMD in subshell with given stdin JSON (exit inside cmd must not kill test harness)
run_stop() { echo "$1" | bash -c "$STOP_CMD" 2>&1; }

# Case 1: stop_hook_active=true → silent (kills the 9x block loop)
out=$(run_stop '{"hook_event_name":"Stop","stop_hook_active":true}')
if [ -z "$out" ]; then
  log_pass "stop_hook_active=true silent (kills loop)"
else
  log_fail "stop_hook_active=true must be silent (got: ${out:0:80})"
fi

# Case 2: non-main branch + dirty → silent (dev branch passthrough, user's intent)
current=$(git branch --show-current)
out=$(run_stop '{"hook_event_name":"Stop","stop_hook_active":false}')
if [ -z "$out" ]; then
  log_pass "non-main branch ($current) passthrough despite dirty tree"
else
  log_fail "non-main branch should pass through (got: ${out:0:80})"
fi

# Case 3: main branch + dirty → warn (protect main from pollution)
tmprepo=$(mktemp -d)
git init -q -b main "$tmprepo" 2>/dev/null || { git init -q "$tmprepo"; git -C "$tmprepo" symbolic-ref HEAD refs/heads/main; }
git -C "$tmprepo" config user.email t@t; git -C "$tmprepo" config user.name t
touch "$tmprepo/dirty.txt"
out=$(cd "$tmprepo" && run_stop '{"hook_event_name":"Stop","stop_hook_active":false}')
echo "$out" | grep -q "additionalContext" && log_pass "main+dirty triggers warn" || log_fail "main+dirty should warn (got: ${out:0:80})"
rm -rf "$tmprepo"

# Case 4: main branch + clean → silent (no false alarm on clean main)
tmprepo2=$(mktemp -d)
git init -q -b main "$tmprepo2" 2>/dev/null || { git init -q "$tmprepo2"; git -C "$tmprepo2" symbolic-ref HEAD refs/heads/main; }
out=$(cd "$tmprepo2" && run_stop '{"hook_event_name":"Stop","stop_hook_active":false}')
if [ -z "$out" ]; then
  log_pass "main+clean silent (no false alarm)"
else
  log_fail "main+clean should be silent (got: ${out:0:80})"
fi
rm -rf "$tmprepo2"

# Simulate the UserPromptSubmit branch check (reads prompt from stdin JSON)
UPS_CMD=$(python3 -c "
import json
d=json.load(open('$HOOK_DIR/sdd-hooks.json'))
print(d['hooks']['UserPromptSubmit'][0]['hooks'][1]['command'])
")

current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
  echo '{"prompt":"帮我实现一个功能"}' | bash -c "$UPS_CMD" 2>&1 | grep -q "sdd-flow-git-warn" && log_pass "main branch warning triggered" || log_fail "main branch warning not triggered"
else
  # On non-main branch, verify the command DOESN'T trigger a false positive
  output=$(echo '{"prompt":"帮我实现一个功能"}' | bash -c "$UPS_CMD" 2>&1) || true
  if [ -z "$output" ]; then
    log_pass "no false warning on non-main branch ($current_branch)"
  else
    log_fail "unexpected output on non-main branch ($current_branch): ${output:0:80}"
  fi
fi

echo ""

# ── Edge case: command with leading whitespace ──
echo "## Edge cases"

test_guard "leading whitespace '  git push'" 2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"  git push"}}'
test_guard "leading spaces '   git merge main'" 2 '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"   git merge main"}}'
# ponytail: tab prefix edge case skipped — Claude Code never sends tab prefixes in JSON

echo ""

# ── Summary ──
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ E2E tests failed"
  exit 1
else
  echo "✅ All E2E tests passed"
  exit 0
fi
