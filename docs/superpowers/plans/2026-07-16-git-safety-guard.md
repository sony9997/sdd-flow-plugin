# Git Safety Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4-layer git safety constraints to sdd-flow-plugin: PreToolUse hard-block on merge-to-main/git-push, UserPromptSubmit soft-warn on main-branch dev, Stop soft-warn on dirty tree, and skill-level branch/clean checks in sdd-flow + sdd-gate.

**Architecture:** One new shell script (`git-guard.sh`) as the hard-gate engine, injected via a new PreToolUse Bash matcher in `sdd-hooks.json`. Two printf-based soft-reminders added to UserPromptSubmit and a new Stop hook. Eight lines of instruction added to sdd-flow SKILL.md and sdd-gate SKILL.md for the skill-layer checks.

**Tech Stack:** POSIX sh, python3 (for stdin JSON parsing), printf (for hook text injection)

## Global Constraints

- All hook commands must work with `${CLAUDE_PLUGIN_ROOT}` prefix; fallback comment for manual install
- RTK rewrites `git push` → `rtk git push` but not `git merge`; guard must match both patterns
- S1 changes are exempt from branch/dirty checks
- Hard blocks exit 1, soft warnings exit 0 with printf to stderr

---

### Task 1: Create git-guard.sh

**Files:**
- Create: `hooks/git-guard.sh`

**Interfaces:**
- Consumes: stdin JSON with `tool_input.command` field
- Produces: exit 0 (allow) or exit 1 (block), stderr message on block

- [ ] **Step 1: Write the guard script**

```bash
#!/bin/bash
# Git Safety Guard — PreToolUse hook for Bash tool
# Reads stdin JSON from Claude Code, extracts tool_input.command,
# blocks dangerous git operations (merge to main, push without confirmation).
# RTK-aware: matches both "git ..." and "rtk git ..." patterns.
set -e

INPUT_JSON=$(cat)

# Parse command from stdin JSON
COMMAND=$(python3 << 'EOF'
import json, sys

try:
    data = json.loads(sys.stdin.read())
    cmd = data.get("tool_input", {}).get("command", "")
    print(cmd)
except Exception:
    print("")
EOF
<<< "$INPUT_JSON")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Normalize: strip leading whitespace
NORMALIZED=$(echo "$COMMAND" | sed 's/^[[:space:]]*//')

# Rule 1: Block merge to main/master (both raw git and RTK-wrapped)
# Examples: "git merge main", "git merge origin/main", "rtk git merge master"
if echo "$NORMALIZED" | grep -qE '^(rtk )?git merge .*(main|master)'; then
  printf '\n🚫 <sdd-flow-git-block> 禁止合并到主干分支 (main/master)。\n   如需合并，请手动在终端执行。\n</sdd-flow-git-block>\n\n' >&2
  exit 1
fi

# Rule 2: Block git push without user confirmation (both raw git and RTK-wrapped)
# Examples: "git push", "git push origin main", "rtk git push --force"
if echo "$NORMALIZED" | grep -qE '^(rtk )?git push'; then
  printf '\n🚫 <sdd-flow-git-block> 推送需用户确认。\n   用 ! git push 前缀绕过此检查（terminal 中执行）\n   或回复 "确认推送" 后我手动放行。</sdd-flow-git-block>\n\n' >&2
  exit 1
fi

# Rule 3: Soft-remind conventional commit format
if echo "$NORMALIZED" | grep -qE '^(rtk )?git commit'; then
  printf '\n💡 <sdd-flow-git-hint> 请使用 conventional commit 格式：feat:/fix:/refactor:/docs:/test:/chore:/perf:/ci:\n</sdd-flow-git-hint>\n\n' >&2
fi

exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x hooks/git-guard.sh
```

- [ ] **Step 3: Test with mock stdin — scenario: merge to main blocked**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 1, stderr contains "禁止合并到主干分支"

- [ ] **Step 4: Test — scenario: merge to feature branch allowed**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge feature/bar"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 0

- [ ] **Step 5: Test — scenario: git push blocked**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 1, stderr contains "推送需用户确认"

- [ ] **Step 6: Test — scenario: RTK-wrapped git push blocked**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git push origin main"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 1, stderr contains "推送需用户确认"

- [ ] **Step 7: Test — scenario: RTK-wrapped git merge to main blocked**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git merge origin/main"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 1

- [ ] **Step 8: Test — scenario: git commit gets soft hint**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"wip\""},"session_id":"test"}' | hooks/git-guard.sh 2>&1
echo "EXIT: $?"
```
Expected: EXIT: 0, stderr contains "conventional commit"

- [ ] **Step 9: Test — scenario: non-git command passes through**

```bash
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"test"}' | hooks/git-guard.sh
echo "EXIT: $?"
```
Expected: EXIT: 0, no output

---

### Task 2: Modify hooks/sdd-hooks.json

**Files:**
- Modify: `hooks/sdd-hooks.json`

**Interfaces:**
- Consumes: git-guard.sh at `${CLAUDE_PLUGIN_ROOT}/hooks/git-guard.sh`
- Produces: 3 hook entries (PreToolUse Bash, UserPromptSubmit git warn, Stop)

- [ ] **Step 1: Add PreToolUse Bash matcher, UserPromptSubmit branch check, and Stop hook**

Read current `hooks/sdd-hooks.json` first, then replace entire file with:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "实现|新增|增加|添加|修复|删除|重构|开发|修改|改动|调整|优化|完善|升级|更新|生成|搭建|创建|支持|做个|做一下|加个|加上|改下|改一下|写个|写一下|弄|搞|build|add|create|update|change|modify|enhance|improve|support|fix|implement|refactor|delete|remove|bug|feat",
        "hooks": [
          {
            "type": "command",
            "command": "printf '<sdd-flow-reminder>MUST：本请求疑似开发类（代码/功能/bug 变更）。禁止直接写码。第一步 invoke sdd-flow skill 做 S1/S2/S3 分级，判级须显式输出「S1|S2|S3 + 一句理由」，再按分级路径执行（S1 直接写+TDD，S2 openspec-propose，S3 全闭环）。非开发类请求忽略。</sdd-flow-reminder>'"
          },
          {
            "type": "command",
            "command": "branch=$(git branch --show-current 2>/dev/null); if [ \"$branch\" = \"main\" ] || [ \"$branch\" = \"master\" ]; then printf '<sdd-flow-git-warn>⚠️ 当前在 %s 分支。S2/S3 变更请先 git switch -c feat/&lt;任务名&gt; 开新分支。S1 可忽略。</sdd-flow-git-warn>' \"$branch\"; fi"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "printf '<sdd-flow-enforce>写码动作前自检：本会话已 invoke sdd-flow 并输出 S1/S2/S3 分级？未分级则停下先 invoke sdd-flow。S1 可继续写，S2/S3 须按路径走（proposal/brainstorm/plan）。已分级则忽略。</sdd-flow-enforce>'"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/git-guard.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "if [ -n \"$(git status --porcelain 2>/dev/null)\" ]; then printf '<sdd-flow-stop-warn>⚠️ 有未提交的改动。建议 git add + git commit 或 git stash 保存。</sdd-flow-stop-warn>'; fi"
          }
        ]
      }
    ]
  }
}
```

> **Manual install fallback**: Replace `${CLAUDE_PLUGIN_ROOT}` with absolute path `~/.claude/plugins/cache/sdd-flow/sdd-flow/1.3.1` if the plugin root env var is not available.

- [ ] **Step 2: Validate JSON syntax**

```bash
python3 -c "import json; json.load(open('hooks/sdd-hooks.json')); print('JSON valid')"
```
Expected: JSON valid

---

### Task 3: Modify sdd-flow SKILL.md — S2/S3 git checks

**Files:**
- Modify: `skills/sdd-flow/SKILL.md`

**Interfaces:**
- Consumes: git CLI available in PATH
- Produces: Model follows git-check instruction at Step 0 and Phase 5

- [ ] **Step 1: Add S2/S3 branch + dirty check after Step 0 classification**

After line 34 (`判定后**自动分支**：`), insert:

```markdown
**S2/S3 分支检查**（分级后、分支路由前执行，S1 豁免）：
- 执行 `git branch --show-current`，若为 `main` 或 `master`，提醒「⚠️ 当前在主干分支。S2/S3 变更请先 `git switch -c feat/<任务名>` 开新分支」
- 执行 `git status --porcelain`，有输出则提醒「⚠️ working tree 不干净，有未提交改动。建议先 `git stash` 或 commit 清理后再开始新变更」
- 两项检查通过后方可进入后续流程

```

Wait — this is instruction text for the model. I need to use Edit, not a code block with `- [ ]`. Let me think about this differently.

Actually, the plan format from writing-plans says to include exact code in steps. Let me be more precise about what gets inserted where.

- [ ] **Step 1: Insert S2/S3 git check block into sdd-flow SKILL.md**

Target: after the "判定后**自动分支**：" line (line 34 in the current file) and before the S1 bullet.

Insert the following markdown block:

```markdown
**S2/S3 分支与工作区检查**（分级后、分支路由前执行，S1 豁免）：
- 执行 `git branch --show-current`，若为 `main` 或 `master`，提醒「⚠️ 当前在主干分支。S2/S3 变更请先 `git switch -c feat/<任务名>` 开新分支」
- 执行 `git status --porcelain`，有输出则提醒「⚠️ working tree 不干净，有未提交改动。建议先 `git stash` 或 commit 清理后再开始新变更」
- 两项检查通过后方可进入后续 S2/S3 流程

```

- [ ] **Step 2: Add archive-before-clean check in S3 Phase 5 description**

Target: in the S3 全闭环总览 table, Phase 5 "门禁" column, after "E2E ✓ 且 verification ✓ 且 changes 已归档"

Change the Phase 5 "门禁" cell from:
```
E2E ✓ 且 verification ✓ 且 changes 已归档
```
to:
```
E2E ✓ 且 verification ✓ 且 changes 已归档 + git status clean（改动已全部 commit）
```

And in the "5 E2E + 归档 + 沉淀" section, add a note:

Target: after "调 `openspec-archive` 归档 → **经验沉淀**" (line 64)

```markdown
  - **archive 前**：确认 `git status --porcelain` clean 或改动已全部 commit；未 commit 的变更不应归档
```

- [ ] **Step 3: Verify sdd-flow SKILL.md is still valid markdown with valid frontmatter**

Read the file and confirm frontmatter is intact, no broken YAML.

---

### Task 4: Modify sdd-gate SKILL.md — git clean check

**Files:**
- Modify: `skills/sdd-gate/SKILL.md`

**Interfaces:**
- Consumes: none (pure instruction text)
- Produces: Model checks git status during gate self-check

- [ ] **Step 1: Add git clean question to the 6 self-check questions**

Target: replace the "自检六问" section title comment and add a 7th question.

Change the heading from:
```markdown
## 自检六问（任一阶段结束前）
```
to:
```markdown
## 自检七问（任一阶段结束前）
```

And change the closing from:
```markdown
全否 → 放行；任一是 → 先修再走。
```
to:
```markdown
7. archive/CHANGELOG 追加前 git status clean？（S2/S3，改动已全部 commit？）

全否 → 放行；任一是 → 先修再走。
```

---

### Task 5: Integration verification

**Files:**
- Verify: `hooks/git-guard.sh`, `hooks/sdd-hooks.json`, `skills/sdd-flow/SKILL.md`, `skills/sdd-gate/SKILL.md`

- [ ] **Step 1: Run all git-guard.sh test scenarios again**

```bash
echo "=== Test 1: merge to main blocked ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"

echo "=== Test 2: merge to feature allowed ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge feature/bar"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"

echo "=== Test 3: push blocked ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"

echo "=== Test 4: RTK push blocked ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk git push origin main"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"

echo "=== Test 5: commit hint ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m wip"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"

echo "=== Test 6: non-git passthrough ==="
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test"}' | hooks/git-guard.sh 2>&1; echo "EXIT: $?"
```

Expected:
- Test 1,3,4: EXIT: 1
- Test 2,5,6: EXIT: 0

- [ ] **Step 2: Validate sdd-hooks.json is well-formed**

```bash
python3 -c "import json; d=json.load(open('hooks/sdd-hooks.json')); print('Stop hooks:', len(d['hooks'].get('Stop',[]))); print('PreToolUse hooks:', len(d['hooks'].get('PreToolUse',[]))); print('UserPromptSubmit hooks:', len(d['hooks'].get('UserPromptSubmit',[])))"
```
Expected: Stop hooks: 1, PreToolUse hooks: 2, UserPromptSubmit hooks: 1

- [ ] **Step 3: Quick sanity — check all 4 modified files exist and are non-empty**

```bash
wc -l hooks/git-guard.sh hooks/sdd-hooks.json skills/sdd-flow/SKILL.md skills/sdd-gate/SKILL.md
```

---

### Task 6: CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Append CHANGELOG entry**

```markdown
- 2026-07-16 git-safety-guard: 四层 git 安全约束（硬拒绝 merge 到主干+push / 软提醒分支+dirty / skill 层分支检查） (S2)
```
