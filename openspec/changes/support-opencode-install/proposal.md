# Proposal: support-opencode-install

## Why

sdd-flow 目前是 Claude Code 专属 plugin（靠 `.claude-plugin/plugin.json` + `marketplace.json` 分发）。用户希望在 [OpenCode](https://opencode.ai)（sst/opencode，开源终端 AI 编码 agent）中也能装上并用起来 sdd-flow 的分级闭环。

调研确认 OpenCode **原生兼容 Claude 的 `SKILL.md` 格式**：扫描 `.claude/skills/<name>/SKILL.md`、`.opencode/skills/`、`~/.claude/skills/`，frontmatter 只认 `name`+`description`（未知字段忽略）。本仓库三个 skill 的 `name` 均匹配目录名、description 合规 —— **内容零改动即可被 OpenCode 发现**。

真正缺的是「分发路径」与「hook 闸门」两件事：

- OpenCode 不扫仓库根的 `skills/`（那是 Claude Code plugin.json 解析的），也无 Claude marketplace 等价物。
- sdd-hooks.json 是 Claude 声明式 hook（UserPromptSubmit 分级提醒 + PreToolUse 写码自检），OpenCode plugin 是 TS/JS 模块 + event hooks，**格式不兼容**。

## What Changes

1. **新增 install 脚本** `scripts/install-opencode.sh`：幂等把 `skills/*` 拷到 `~/.claude/skills/`（OpenCode 全局自动发现；同时是 Claude Code 用户级 skills 目录，双工具兼容）。
2. **hooks 降级**：sdd-flow 的 hook 本就是软提醒（printf 注入文本，靠模型自觉，非硬拦截），等价行为可用 `AGENTS.md` 规则片段 + skill description 语义触发达成。提供可粘贴的 rules 片段，不写 TS plugin。
3. **README 新增「OpenCode 安装」章节**：一键脚本 + 手动步骤 + 能力差异说明（软闸门 vs 硬提醒）。
4. **验收脚本** `scripts/verify-opencode.sh`：检查三个 skill 是否落到 OpenCode 扫描路径且 name 匹配。

## Capabilities

### New Capabilities
- **opencode-install**：把 sdd-flow skills 装到 OpenCode 扫描路径并验证可发现；提供软闸门规则片段。

### Modified Capabilities
- 无（Claude Code plugin 侧不动）。

## Impact
- 新增：`scripts/install-opencode.sh`、`scripts/verify-opencode.sh`、README 章节、`docs/opencode-rules.md`（rules 片段）。
- 复用：现有 `skills/sdd-flow`、`skills/sdd-gate`、`skills/sdd-progress`（零改动）。
- 不影响：Claude Code plugin 分发链路（`.claude-plugin/`、`hooks/sdd-hooks.json` 不动）。
- 依赖：目标机有 `~/.claude/skills/` 可写权限（OpenCode 与 Claude Code 共用该路径）。

## Non-goals
- 不重写 skills 内容以适配 OpenCode（已原生兼容）。
- 不写 `.opencode/plugins/sdd-flow.ts` 复刻硬 hook（软提醒不值得 TS 工程，YAGNI）。
- 不做 OpenCode marketplace 发布（其 marketplace 仍实验性）。
- 不处理 OpenCode 的 agent/command 定义（sdd-flow 无此组件）。
