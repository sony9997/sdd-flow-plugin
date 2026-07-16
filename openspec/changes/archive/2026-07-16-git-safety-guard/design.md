# 技术设计：Git Safety Guard

## 方案概述

四层约束，从硬到软：

```
PreToolUse (Bash) ──→ 硬拦截 merge/push (exit 1)
UserPromptSubmit ──→ 软提醒 main 分支 (printf)
Stop ──→ 软提醒未提交 (printf)
sdd-flow Step 0 ──→ S2/S3 分支+dirty 检查 (skill 指令)
sdd-gate ──→ archive 前 clean 检查 (skill 指令)
```

## 技术细节

### 1. git-guard.sh（PreToolUse Bash hook）

**输入**：stdin JSON
```json
{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git merge main"},"session_id":"..."}
```

**逻辑**：
```
1. python3 解析 stdin JSON
2. 提取 tool_input.command
3. 匹配规则（优先级从高到低）：

   A. git merge *main* | git merge *master*
      | rtk git merge *main* | rtk git merge *master*
      → echo "🚫 禁止合并到主干分支" >&2 → exit 1

   B. git push* | rtk git push*
      → echo "🚫 推送需确认。用 ! git push 绕过此检查" >&2 → exit 1

   C. git commit* | rtk git commit*
      → echo "💡 请使用 conventional commit: feat:/fix:/refactor:/docs:/test:/chore:" >&2 → exit 0

4. 默认放行 exit 0
```

**注意**：RTK 改写 `git push` → `rtk git push`，但不改写 `git merge`。匹配需同时覆盖双模式。

**Python3 选择**：比 jq 更可靠，不需要额外依赖，Claude Code 运行环境必有 python3。

### 2. hooks/sdd-hooks.json 修改

#### PreToolUse 追加

现有 2 个 PreToolUse matcher：`Edit|Write|MultiEdit|NotebookEdit`（sdd-flow-enforce）和 `*`（用户 settings.json 中的 observe.sh）。

新增第 3 个：

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/git-guard.sh"
    }
  ]
}
```

> 为什么用 `${CLAUDE_PLUGIN_ROOT}`：插件安装后自动注入此变量，保证路径正确。

> 为什么不合并到现有 PreToolUse matchers：matcher 隔离，Bash 只跑 git-guard，写入只跑 enforce，职责清晰。

#### UserPromptSubmit 追加

现有 matcher 命中开发动词时注入 `<sdd-flow-reminder>`。追加一段 git 检查命令：

```json
{
  "type": "command",
  "command": "branch=$(git branch --show-current 2>/dev/null); if [ \"$branch\" = \"main\" ] || [ \"$branch\" = \"master\" ]; then printf '<sdd-flow-git-warn>⚠️ 当前在 %s 分支。S2/S3 变更请先 git switch -c feat/&lt;任务名&gt; 开新分支。S1 可忽略。</sdd-flow-git-warn>' \"$branch\"; fi"
}
```

#### Stop hook 新增

```json
"Stop": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "if [ -n \"$(git status --porcelain 2>/dev/null)\" ]; then printf '<sdd-flow-stop-warn>⚠️ 有未提交的改动。建议 git add + git commit 或 git stash 保存。</sdd-flow-stop-warn>'; fi"
      }
    ]
  }
]
```

### 3. sdd-flow SKILL.md 修改

Step 0 分级后，S2/S3 路径追加：

```markdown
**S2/S3 分支检查**（分级后执行）：
- 执行 `git branch --show-current`，若为 main/master，提醒「请先 `git switch -c feat/<任务名>` 开分支」
- 执行 `git status --porcelain`，有残留改动则提醒「当前 working tree 不干净，建议先清理」
- S1 豁免此检查
```

S3 阶段 5 archive 前：

```markdown
- archive 前确认 `git status --porcelain` 为 clean 或改动已 commit
```

### 4. sdd-gate SKILL.md 修改

自检六问追加：

```markdown
7. archive/CHANGELOG 前 git status clean？（S2/S3）
```

## RTK 交互

当前用户 settings.json PreToolUse 有 `rtk hook claude`，matcher 为 `Bash`。执行顺序由 Claude Code 决定。

**防御策略**：guard 脚本匹配 `git` 和 `rtk git` 双模式，无论 RTK 在之前还是之后都不影响。

已实证：
- `rtk hook claude` 对 `git push` 改写为 `rtk git push`，exit 0
- `rtk hook claude` 对 `git merge` 不改写，exit 0

## 风险与权衡

| 风险 | 缓解 |
|------|------|
| Claude Code hook 不支持 `${CLAUDE_PLUGIN_ROOT}` | 降级为绝对路径 `/Users/hed/.claude/plugins/cache/sdd-flow/...` 或 `~/.claude/...` |
| bash hook 执行顺序不确定 | 双模式匹配，覆盖 RTK 前后两种场景 |
| S1 豁免可能被滥用 | S1 范围小（1-2 文件、无风险），滥用即 S2，会被分级升档 |
