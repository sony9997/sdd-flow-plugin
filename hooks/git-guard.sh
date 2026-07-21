#!/bin/bash
# Git Safety Guard — PreToolUse hook for Bash tool
# Reads stdin JSON from Claude Code, extracts tool_input.command,
# blocks dangerous git operations (merge to main, push without confirmation).
# RTK-aware: matches both "git ..." and "rtk git ..." patterns.
set -e

INPUT_JSON=$(cat)

# Parse command from stdin JSON
COMMAND=$(echo "$INPUT_JSON" | python3 -c '
import json, sys

try:
    data = json.loads(sys.stdin.read())
    cmd = data.get("tool_input", {}).get("command", "")
    print(cmd)
except Exception:
    print(""
)' )

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Normalize: strip leading whitespace
NORMALIZED=$(echo "$COMMAND" | sed 's/^[[:space:]]*//')

# Rule 1: Block merge to main/master (both raw git and RTK-wrapped)
# Examples: "git merge main", "git merge origin/main", "rtk git merge master"
if echo "$NORMALIZED" | grep -qE '^(rtk )?git merge .*(main|master)'; then
  printf '\n🚫 <sdd-flow-git-block> 禁止合并到主干分支 (main/master)。\n   如需合并，请手动在终端执行。\n</sdd-flow-git-block>\n\n' >&2
  exit 2
fi

# Rule 2: Block git push without user confirmation (both raw git and RTK-wrapped)
# Examples: "git push", "git push origin main", "rtk git push --force"
if echo "$NORMALIZED" | grep -qE '^(rtk )?git push'; then
  printf '\n🚫 <sdd-flow-git-block> 推送需用户确认。\n   用 ! git push 前缀绕过此检查（terminal 中执行）\n   或回复 "确认推送" 后我手动放行。</sdd-flow-git-block>\n\n' >&2
  exit 2
fi

# Rule 3: Soft-remind conventional commit format
if echo "$NORMALIZED" | grep -qE '^(rtk )?git commit'; then
  printf '\n💡 <sdd-flow-git-hint> 请使用 conventional commit 格式：feat:/fix:/refactor:/docs:/test:/chore:/perf:/ci:\n</sdd-flow-git-hint>\n\n' >&2
fi

exit 0
