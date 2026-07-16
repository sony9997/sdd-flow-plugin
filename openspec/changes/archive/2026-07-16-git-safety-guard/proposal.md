## Why

sdd-flow-plugin 当前对 git 操作零约束。模型可能在 main 分支上直接开发、自动合并到主干、推送未经确认——这些都是实际风险。需要在 hook 层面加硬拦截 + 软提醒，在 skill 层面加分支/clean 检查。

## What Changes

**新增 1 个脚本，修改 4 个文件：**

1. `hooks/git-guard.sh` — 新增：PreToolUse Bash 守卫脚本，读 stdin JSON 提取命令，匹配危险模式 exit 1
2. `hooks/sdd-hooks.json` — 修改：PreToolUse 追加 Bash matcher（git-guard）、UserPromptSubmit 追加分支检查、新增 Stop hook
3. `skills/sdd-flow/SKILL.md` — 修改：Step 0 追加 S2/S3 分支检查 + dirty 检查
4. `skills/sdd-gate/SKILL.md` — 修改：自检六问追加 git clean 检查项

## Capabilities

### New Capabilities
- 硬拒绝 `git merge main/master`（PreToolUse 拦截）
- 硬拒绝 `git push`（PreToolUse 拦截，需 `!` 前缀绕过）
- 会话结束时 dirty tree 提醒（Stop hook）
- main 分支开发警告（UserPromptSubmit 追加）

### Modified Capabilities
- sdd-flow Step 0：S2/S3 路径增加分支 + dirty 检查
- sdd-gate 自检：增加 git clean 检查项

## Non-Goals
- 不检查 S1 变更的分支/clean 状态（豁免）
- 不强制 commit message 格式（仅软提醒）
- 不阻止 `git merge` 到非主分支（feature 分支内合并正常）
- 不做 pre-commit hook（那是 git hooks 范畴，非 Claude Code hooks）

## Impact
- 新增：`hooks/git-guard.sh`（~40 行）
- 修改：`hooks/sdd-hooks.json`（~10 行新增）
- 修改：`skills/sdd-flow/SKILL.md`（~8 行新增）
- 修改：`skills/sdd-gate/SKILL.md`（~3 行新增）
- 不影响：scripts/、tests/、openspec/、skills/sdd-progress/、.claude-plugin/
