# 归档记录

## 基本信息
- **变更名称**：git-safety-guard
- **归档日期**：2026-07-16
- **负责人**：sony9997
- **分级路径**：S2（半闭环）

## 变更摘要
给 sdd-flow-plugin 增加四层 git 安全约束：PreToolUse Bash 硬拒绝（merge 到主干、未经确认的 push）、UserPromptSubmit 软提醒（main 分支开发）、Stop hook 软提醒（会话结束未提交改动）、skill 指令层（sdd-flow Step 0 分支+dirty 检查、sdd-gate 自检 git clean）。

## 关键决策
1. **硬拦截用 exit 1**：PreToolUse Bash hub 脚本读 stdin JSON，匹配危险命令直接 exit 1 拒绝执行。软提醒用 printf 注入文本（exit 0）。
2. **push 绕过用 `!` 前缀**：`! git push` 会改变命令字符串，不再匹配 guard 正则→放行。无需状态文件。
3. **RTK 双模式匹配**：用户 settings.json 中 `rtk hook claude` 会将 `git push` 改写为 `rtk git push`，但不改写 `git merge`。guard 脚本同时匹配两种形式。
4. **S1 豁免分支/dirty 检查**：S1 变更范围小（1-2 文件），开分支成本>收益。S2/S3 必须检查。
5. **Stop hook 用空 matcher**：`"matcher": ""` 命中所有 Stop 事件，非空 matcher 可能漏触发。

## 技术栈
- POSIX sh + python3（json 解析）
- grep -qE 正则匹配
- printf 注入 Claude Code hook 文本
- shell 测试脚本（TDD，无 bats）

## 测试结果
- 集成测试：6 场景（merge 拦截/push 拦截/RTK 双模式/commit 提示/非 git 放行）PASS
- E2E 测试：33 场景（18 guard + 6 stderr + 8 JSON 结构 + 1 Stop）PASS

## 审查记录
- 路径：S2（subagent-driven-development Task 1 派子代理，Task 2 派子代理，Task 3-6 inline）
- 质量保证：TDD（每 commit GREEN）+ sdd-gate 七问自检全过 + E2E 33/33 pass
- Task 1 子代理 review：spec ✅, 质量 Approved（merge regex 含 main/master 子串误杀风险，brief 设计决定，接受）

## 已知问题
- merge regex `.*(main|master)` 会误杀含 `main`/`master` 子串的分支名（如 `git merge feature/maintenance`），概率极低，当前不修
- `${CLAUDE_PLUGIN_ROOT}` 环境变量可能不可用→需降级为绝对路径（plan 已备注）

## 后续优化建议
- 若 merge regex 误杀频发，收紧为 `git merge (origin/)?(main|master)$`
- 推送确认可升级为两阶段（首次拒绝+记录状态+二次放行），当前 `!` 前缀方案够用
- 可增加 PreToolUse Bash hook 对 `git branch -d main` 等危险操作的拦截

## 相关文件
- proposal.md / design.md / tasks.md / specs/git-guard-hook/spec.md
- 实现：`hooks/git-guard.sh`、`hooks/sdd-hooks.json`、`skills/sdd-flow/SKILL.md`、`skills/sdd-gate/SKILL.md`
- 测试：`tests/e2e-git-safety-guard.sh`
- 实现计划：`docs/superpowers/plans/2026-07-16-git-safety-guard.md`
