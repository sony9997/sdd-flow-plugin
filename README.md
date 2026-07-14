# SDD Flow — 协同开发编排套件

OpenSpec 管「做什么」，Superpowers 管「怎么做」，本 plugin 把两者串成自动分级闭环。据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼。

## Skills

- **`sdd-flow`**：主编排。任何开发请求自动触发，Step 0 按四信号（范围/决策/风险/UI）判 S1/S2/S3 → S1 直接写+TDD 全自动；S2 半闭环；S3 全闭环（propose→brainstorm→plan→子代理TDD+两阶段Review→archive→经验沉淀）。bug 命中 S2/S3 先跑 RCA。S2/S3 在减速点停下确认。
- **`sdd-gate`**：四大误区避坑守门员（绕过 Superpowers / 混淆 specs 与 plans / 全栈 UI 靠纯文字 / 跳过 E2E 只跑单元测试）。自检六问，含进度/经验更新检查。
- **`sdd-progress`**：项目级实时进度生成。纯读取 `openspec changes/specs` + 项目根 `CHANGELOG.md` + `git log`，渲染【进行中｜最近完成｜下一步】。不落盘、零 drift。

## 依赖（必须先装）

- **OpenSpec**：`openspec-propose` / `openspec-archive`
- **Superpowers**：`superpowers:brainstorming` / `writing-plans` / `subagent-driven-development` / `test-driven-development` / `systematic-debugging` / `executing-plans` / `verification-before-completion`（`dispatching-parallel-agents` 仅调试时按需，非常规依赖）
- **claude-mem**（可选）：`claude-mem:save_memory` 存经验，跨项目语义召回。未装则经验降级存项目 `openspec/LESSONS.md`。

本 plugin 只含编排层，不重复实现上述能力。

## 进度与经验机制（v1.3.0+）

三层，职责正交：

| 层 | 载体 | 谁写 | 性质 |
|---|---|---|---|
| 需求级进度 | `openspec/changes/<变更名>/tasks.md` | sdd-flow 每 task 完成勾选 | 实时、随变更 |
| 项目级进度 | `sdd-progress` 实时生成 | 按需读取，不落盘 | 实时、零 drift |
| 项目历史 | 项目根 `CHANGELOG.md` | sdd-flow 在 S2/S3 完成时追加 | 只增、不可变 |

经验：S2/S3 完成时自动蒸馏（失败记录/review 发现/brainstorm 取舍），存 claude-mem（跨项目召回）或降级 LESSONS.md。S1 不蒸馏。

## 安装

```bash
/plugin marketplace add sony9997/sdd-flow-plugin
/plugin install sdd-flow@sdd-flow
```

## 在 OpenCode 中安装

[OpenCode](https://opencode.ai) 原生兼容 Claude 的 `SKILL.md` 格式（全局扫描 `~/.config/opencode/skills/`、`~/.claude/skills/`、`~/.agents/skills/`，项目级扫 `.opencode/skills/` 等），三个 skill 内容零改动即可被发现。

一键安装（拷到 `~/.config/opencode/skills/`，OpenCode 原生全局目录）：

```bash
git clone https://github.com/sony9997/sdd-flow-plugin.git
cd sdd-flow-plugin
./scripts/install-opencode.sh
./scripts/verify-opencode.sh   # 自检三 skill 落位 + name 匹配
```

自定义目标（如项目级 `.opencode/skills/`）：

```bash
SDD_INSTALL_DIR=./.opencode/skills ./scripts/install-opencode.sh
```

重启 OpenCode 或开新会话后，sdd-flow/sdd-gate/sdd-progress 出现在 skill 工具列表。

### 软闸门（替代 Claude hook）

OpenCode 无声明式 hook。把 `docs/opencode-rules.md` 的片段粘进项目 `AGENTS.md`，复刻分级软闸门（软提醒，靠模型自觉，可靠性 ~85%，低于 Claude 侧硬 matcher 的 ~98%）。

### 前置依赖

同 Claude 侧：OpenSpec（`openspec-propose`/`openspec-archive`）、Superpowers（`brainstorming`/`writing-plans`/`test-driven-development` 等）需按各自官方方式安装到 OpenCode。本套件只含编排层。

## 升级

若已安装旧版本，可通过以下方式升级：

```bash
# 推荐方式
/plugin marketplace update sony9997/sdd-flow-plugin
/plugin update sdd-flow

# 或先卸载再安装
/plugin remove sdd-flow
/plugin install sdd-flow@sdd-flow
```

装完后，开发类请求（含「实现/新增/修复/删除/重构/开发/fix/implement/refactor/delete/remove」等动词）会自动注入提醒，触发 sdd-flow 分级。

## 自动触发机制

`hooks/sdd-hooks.json` 配了 `UserPromptSubmit` hook，匹配开发动词时注入 `<sdd-flow-reminder>`，把自动触发可靠性从 ~85% 拉到 ~98%。

### 自定义触发词

编辑 `hooks/sdd-hooks.json` 的 `matcher` 字段，用 `|` 分隔正则关键词：

- 收窄：去掉 `开发` 等泛词，只保留明确写码动词
- 扩宽：加入项目特有动词（如 `迁移|部署`）
- 禁用：删除整个 hooks 文件或清空 matcher

## 排查

提醒注入（`<sdd-flow-reminder>`）只取决于 matcher 是否命中，与依赖装没装无关。依赖缺失不会影响注入，只会让后续 skill 调用失败。

| 症状 | 原因 | 解决 |
|---|---|---|
| 输入开发动词无提醒注入 | plugin 未加载，或 matcher 未命中该词 | `/reload-plugins`；确认动词在 matcher 列表内 |
| sdd-flow skill 调用报 skill not found | plugin 未正确加载 | `/plugin update sdd-flow` 或重装 |
| skill 调用报依赖 skill 不存在（如 openspec/superpowers not found） | OpenSpec / Superpowers 未安装 | 按各自官方方式安装（marketplace 名以官方为准） |
| 提醒误触发（改 README 也注入） | matcher 过宽 | 收窄 `hooks/sdd-hooks.json` matcher |

## 卸载

```bash
/plugin remove sdd-flow
```

卸载后 hook 自动失效（hook 随 plugin 目录移除）。若残留提醒注入，检查 `~/.claude/plugins/` 下是否有 sdd-flow 残留目录，手动删除即可。
