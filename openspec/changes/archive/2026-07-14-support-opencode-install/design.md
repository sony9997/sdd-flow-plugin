# 技术设计：support-opencode-install

## 方案概述

利用 OpenCode 对 `.claude/skills/*/SKILL.md` 的原生扫描，把仓库 `skills/` 分发到 OpenCode 全局发现路径，实现零内容改动的跨工具复用。hook 软提醒降级为规则文本，保持行为等价。

```
仓库源 skills/<name>/SKILL.md
        │  install-opencode.sh（幂等拷贝）
        ▼
~/.claude/skills/<name>/SKILL.md  ← OpenCode 全局扫描 + Claude Code 用户级扫描（双兼容）
```

## 技术选型

| 决策 | 选择 | 理由 |
|---|---|---|
| 分发 | shell 脚本拷贝到 `~/.claude/skills/` | 单源（仓库 skills/ 为唯一真源），幂等；一箭双雕（OpenCode + Claude Code 用户级）；无构建链、无依赖 |
| hook 闸门 | 降级 AGENTS.md/rules 文本片段 | sdd-hooks.json 实测是 printf 软提醒（靠模型自觉），非硬阻断；OpenCode event 体系无 prompt-submit 等价物，写 TS plugin 复刻软提醒投入产出比低 |
| 安装目标 | `~/.claude/skills/` 而非 `.opencode/skills/` | OpenCode 同时扫两者，但 `~/.claude/skills/` 让 Claude Code 用户级也受益，覆盖更广 |

## 备选方案

### A. 仓库内提供 `.opencode/skills/` 镜像（双份维护）—— 否决
两份 skill 源易腐化，更新易漏。违反「single source of truth」。仅当坚持「clone 即用、无脚本」时可选，但拷贝脚本已足够轻。

### B. 软链 `skills/` → `.opencode/skills/` —— 否决
软链跨机器、跨权限（尤其全局安装）脆弱，Windows 不友好。拷贝 + 幂等更稳。

### C. 写 `.opencode/plugins/sdd-flow.ts` 复刻 hook —— 否决（列为 Non-goal）
sdd-flow hook 是软提醒。OpenCode plugin event（`tool.execute.before` 等）面向 tool 级拦截，复刻「prompt 提交时提醒分级」需 spike 是否有 chat.prompt 类 event，且 TS 工程量与「软提醒」收益不匹配。若未来要硬闸门再回头做。

## 实现细节

### install-opencode.sh
- 设 `DEST="${SDD_INSTALL_DIR:-$HOME/.claude/skills}"`，支持环境变量覆盖（OpenCode 优先 `OPENCODE_INSTALL_DIR` 约定）。
- 遍历 `skills/*/`，每个 `<name>` 拷到 `$DEST/<name>/`，`cp -R` 覆盖。
- 拷前校验：源 `SKILL.md` 的 frontmatter `name` 字段 == 目录名（OpenCode 硬性要求，不符则忽略）。
- 幂等：重复运行覆盖同名，不报错。
- 输出已安装 skill 列表 + 提示「OpenCode 重启/新会话生效」。

### verify-opencode.sh
- 检查 `$DEST` 下三个 skill 存在、`name` 匹配、description 非空。
- 退出码：全过 `0`，任一缺失 `1`。

### docs/opencode-rules.md
- 提供两段可粘贴文本：
  1. `AGENTS.md` 片段（项目级软闸门）：复刻 UserPromptSubmit 提醒语义——「开发类请求先 invoke sdd-flow 做分级」。
  2. `~/.config/opencode/` 全局规则（若 OpenCode 支持 global AGENTS.md）。

## 风险与权衡

| 风险 | 缓解 |
|---|---|
| OpenCode 版本演进改扫描路径 | install 脚本 + verify 脚本双层；文档注明「OpenCode ≥ 当前文档版本」 |
| 软闸门依赖模型自觉，分级可能漏触发 | 这与 Claude Code 侧 hook 行为同质（都是软提醒）；description 含触发词增强语义召回；接受降级 |
| `~/.claude/skills/` 与 Claude Code 用户级 skills 冲突 | skill name（sdd-flow/sdd-gate/sdd-progress）具名隔离；同名覆盖属预期升级 |
| Windows 路径 | 脚本 POSIX sh；Windows 用 git-bash/WSL，文档注明 |
