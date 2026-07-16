# Git Guard Hook

## 概述

在 Claude Code 的 PreToolUse/UserPromptSubmit/Stop 三个 hook 环节增加 git 安全约束：硬拒绝危险操作（merge 到主干、未经确认的 push），软提醒不规范行为（main 分支开发、未提交改动、commit 格式）。

## 行为规格

### 功能 1：硬拒绝 merge 到主干

- 触发条件：PreToolUse Bash，command 匹配 `git merge *main*`、`git merge *master*`、`rtk git merge *main*`、`rtk git merge *master*`
- 动作：exit 1，stderr 输出拒绝信息
- 放行条件：其他 git merge（feature 分支间合并）

### 功能 2：硬拒绝 git push

- 触发条件：PreToolUse Bash，command 匹配 `git push*` 或 `rtk git push*`
- 动作：exit 1，stderr 输出「请用 `! git push` 绕过」
- 放行条件：用户用 `! git push` 前缀（Claude Code 的 hook 绕过机制）

### 功能 3：软提醒 main 分支开发

- 触发条件：UserPromptSubmit，命中开发动词，且 `git branch --show-current` 为 main/master
- 动作：注入 `<sdd-flow-git-warn>` 提醒文本
- 放行条件：仅提醒，不拦截。S1 可忽略。

### 功能 4：软提醒未提交改动

- 触发条件：Stop hook（会话结束），`git status --porcelain` 非空
- 动作：注入 `<sdd-flow-stop-warn>` 提醒文本

### 功能 5：软提醒 commit 格式

- 触发条件：PreToolUse Bash，command 匹配 `git commit*` 或 `rtk git commit*`
- 动作：exit 0，stdout 输出 conventional commit 格式提示

### 功能 6：sdd-flow 分支/dirty 检查

- 触发条件：sdd-flow Step 0，分级 S2/S3
- 动作：提醒当前分支名 + dirty 状态，提示开分支
- 豁免：S1 不检查

### 功能 7：sdd-gate git clean 检查

- 触发条件：sdd-gate 自检（S2 完成/S3 阶段 5）
- 动作：检查 `git status --porcelain`，确认改动已 commit

## 验收场景

### 场景 1：正常流程 — merge 到主干被拒绝
Given: working tree clean，当前在 feature 分支
When: 模型执行 `git merge main`
Then: PreToolUse hook exit 1，命令不执行，stderr 显示拒绝信息

### 场景 2：正常流程 — push 被拒绝
Given: working tree clean，有 commit 待推送
When: 模型执行 `git push origin feature/foo`
Then: PreToolUse hook exit 1，命令不执行，stderr 显示「请用 ! git push」

### 场景 3：异常流程 — merge 到非主干放行
Given: 当前在 feature/a，执行 `git merge feature/b`
When: 模型执行该命令
Then: PreToolUse hook exit 0，命令正常执行

### 场景 4：软提醒 — main 分支触发警告
Given: 当前分支 main，用户输入「实现用户登录」
When: UserPromptSubmit hook 触发
Then: 注入 `<sdd-flow-git-warn>` 警告文本，不阻止流程

### 场景 5：软提醒 — 会话结束未提交
Given: working tree dirty（有未 commit 文件）
When: 会话结束，Stop hook 触发
Then: 注入 `<sdd-flow-stop-warn>` 提醒文本

### 场景 6：RTK 交互 — rtk git push 同样被拦截
Given: RTK hook 将 `git push` 改写为 `rtk git push`
When: PreToolUse Bash hook 收到改写后的 command
Then: 守卫脚本匹配 `rtk git push`，exit 1

### 场景 7：S1 豁免 — main 分支 S1 变更不警告
Given: 当前分支 main，用户输入 typo fix，分级 S1
When: sdd-flow Step 0 执行
Then: 不触发分支检查
