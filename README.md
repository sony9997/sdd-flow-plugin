# SDD Flow — 协同开发编排套件

OpenSpec 管「做什么」，Superpowers 管「怎么做」，本 plugin 把两者串成自动分级闭环。据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼。

## Skills

- **`sdd-flow`**：主编排。任何开发请求自动触发，Step 0 按四信号（范围/决策/风险/UI）判 S1/S2/S3 → S1 直接写+TDD 全自动；S2 半闭环；S3 全闭环（propose→brainstorm→plan→子代理TDD+两阶段Review→archive）。S2/S3 在减速点停下确认。
- **`sdd-gate`**：三误区避坑守门员（绕过 Superpowers / 混淆 specs 与 plans / 全栈 UI 靠纯文字）。

## 依赖（必须先装）

- **OpenSpec**：`openspec-propose` / `openspec-apply-change` / `openspec-archive-change`
- **Superpowers**：`superpowers:brainstorming` / `writing-plans` / `subagent-driven-development` / `test-driven-development`

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

装完后，开发类请求（含「实现/新增/修改/修复/删除/移除/重构/fix/implement/delete/remove」等动词）会自动注入提醒，触发 sdd-flow 分级。

## 自动触发机制

`hooks/sdd-hooks.json` 配了 `UserPromptSubmit` hook，匹配开发动词时注入 `<sdd-flow-reminder>`，把自动触发可靠性从 ~85% 拉到 ~98%。matcher 关键词可按需收窄。
