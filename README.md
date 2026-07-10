# SDD Flow — 协同开发编排套件

OpenSpec 管「做什么」，Superpowers 管「怎么做」，本 plugin 把两者串成自动分级闭环。据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼。

## Skills

- **`sdd-flow`**：主编排。任何开发请求自动触发，Step 0 按四信号（范围/决策/风险/UI）判 S1/S2/S3 → S1 直接写+TDD 全自动；S2 半闭环；S3 全闭环（propose→brainstorm→plan→子代理TDD+两阶段Review→archive）。S2/S3 在减速点停下确认。
- **`sdd-gate`**：四大误区避坑守门员（绕过 Superpowers / 混淆 specs 与 plans / 全栈 UI 靠纯文字 / 跳过 E2E 只跑单元测试）。

## 依赖（必须先装）

- **OpenSpec**：`openspec-propose` / `openspec-archive`
- **Superpowers**：`superpowers:brainstorming` / `writing-plans` / `subagent-driven-development` / `test-driven-development` / `executing-plans` / `verification-before-completion`（`dispatching-parallel-agents` 仅调试时按需，非常规依赖）

本 plugin 只含编排层，不重复实现上述能力。

## 安装

```bash
/plugin marketplace add sony9997/sdd-flow-plugin
/plugin install sdd-flow@sdd-flow
```

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
