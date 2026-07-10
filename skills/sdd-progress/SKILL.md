---
name: sdd-progress
description: 项目级实时进度生成 —— 读取 openspec changes/specs + 项目根 CHANGELOG + git log，渲染【进行中｜最近完成｜下一步】三段概览。纯读取、不落盘、零维护。触发词：「项目进度」「进度」「现在在做什么」「项目状态」「sdd progress」「做到哪了」。
license: MIT
metadata:
  author: my-happy-coder
  version: "1.3.0"
  source: sdd-flow v1.3.0 进度层
---

# SDD 项目级进度（实时生成）

一句话：不存进度文件（避免 drift），按需读取现有真相源实时渲染项目进度。

**触发词**：项目进度 / 进度 / 现在在做什么 / 项目状态 / sdd progress / 做到哪了

## 输入源（按可用性拼接）

| 源 | 路径 | 提供什么 |
|---|---|---|
| 进行中变更 | `openspec/changes/*/` | 每个 in-flight 变更 + 其 `tasks.md` 完成度（需求级进度） |
| 已固化能力 | `openspec/specs/` | 项目当前真实的规格面（已完成并 archive 的） |
| 历史轨迹 | 项目根 `CHANGELOG.md` | 最近完成的变更（sdd-flow 在 S2/S3 完成时追加） |
| 提交活动 | `git log`（最近 N 条） | 实际代码进展 |

## 输出结构（三段）

```
【进行中】
- <变更名>：tasks.md X/Y 完成，当前阶段 <plan/执行/...>
  ...

【最近完成】
- [日期] <变更名>：<CHANGELOG 一句话摘要>
  ...（取 CHANGELOG 最近 5 条，或 specs/ 最近 archive）

【下一步建议】
- 进行中变更的下一个未完成 task
- 或从 spec 缺口 / git 未提交改动 推断
```

## 降级（缺源时）

- **openspec 未装 / 无 changes 目录** → 只显示 CHANGELOG + git log，并提示「装 openspec 可看需求级进度」
- **无 CHANGELOG.md** → 历史段显示「暂无归档记录」，其余段照常
- **非 git 仓库** → 跳过 git log 段

## 设计原则

- **纯读取、无副作用**：不写、不改任何文件
- **零 drift**：进度从真相源现算，不存在过期文件
- **职责正交**：CHANGELOG（历史，只增）+ 本 skill（实时，生成）= 完整进度视图
- **与 sdd-flow 协作**：sdd-flow 在 S2/S3 完成时负责更新 CHANGELOG 和 tasks.md；本 skill 只读取呈现

## 备注

- 中断恢复：进行中变更的 `tasks.md` 完成度直接反映实现进度，中断后从此处接续
- 需求级进度（单个变更做到哪）看 `openspec/changes/<变更名>/tasks.md`；项目级进度（整体）用本 skill
