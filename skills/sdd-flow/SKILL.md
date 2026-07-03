---
name: sdd-flow
description: 开发请求的自动分级与执行入口 —— 任何写功能/改代码/修 bug/重构请求都先自动触发本 skill 做 S1/S2/S3 分级（按范围/决策/风险/UI 四信号），S1 直接写+TDD 全自动跑完，S2 走半闭环，S3 走 propose→brainstorm→plan→子代理TDD+两阶段Review→archive 全闭环；S2/S3 在减速点（proposal/brainstorm/Review）停下确认。触发词：实现/新增/修改/重构/写一个/做一个/帮我写/帮我改/fix/implement/refactor/build/create/feature 等开发动词，以及「协同开发」「sdd flow」「完整流程」「从规格到归档」。
license: MIT
metadata:
  author: my-happy-coder
  version: "1.0"
  source: 据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼
---

# SDD 协同开发闭环（OpenSpec × Superpowers）

一句话：OpenSpec 管「做什么」，Superpowers 管「怎么做」，本 skill 把两者串成 `propose → brainstorm → plan → 子代理执行 → archive` 的可追溯闭环。

## Step 0：分级闸门（自动，最先执行）

被触发后第一动作：读用户需求，按下表四信号打分，判定 S1 / S2 / S3。

| 信号 | S1 小 | S2 中 | S3 复杂 |
|---|---|---|---|
| 改动范围 | 1-2 文件、单包 | 单包多文件 | 跨包 / 架构级 |
| 决策含量 | 无（写法明确） | 小（1-2 选择） | 大（多方案，需 design） |
| 风险面 | 低 | 中 | 高（安全 / 数据模型 / 外部契约） |
| UI/交互 | 无或微调 | 单页面 | 多页面复杂交互 |

**升级规则：任一信号命中 S3 → 按 S3 走**（复杂度取最高项，非平均）。分级有歧义时偏保守（取高级别）。用户可强制覆盖（如「这个按 S3 走」）。

判定后**自动分支**：

- **S1 → 直接写（全自动，无需确认）**：直接实现 + `superpowers:test-driven-development`；非平凡逻辑留一个 `assert` 自检或小测试；不开 openspec、不跑 brainstorm。
- **S2 → 半闭环（减速点停）**：`openspec-propose` 出轻量 proposal + specs（design.md 可选）→ `superpowers:writing-plans` 拆几步 → `superpowers:test-driven-development` 执行 → 跑一次 `sdd-gate` 自检三问 → 不必 archive。减速点：proposal、plan 确认。
- **S3 → 全闭环（减速点停）**：走下方「S3 全闭环总览」五阶段。

## S3 全闭环总览

| 阶段 | 做什么 | 调用现有 skill | 产出 | 门禁 |
|---|---|---|---|---|
| 1 对齐 | 需求 → 结构化规格 | `openspec-propose` | proposal.md / design.md / specs/ / tasks.md | 用户确认 proposal |
| 2 头脑风暴 | 苏格拉底式追问、UI 可视化 | `superpowers:brainstorming` | 更新 design、可选 HTML 原型 | 设计批准 |
| 3 计划 | 拆 2-5 分钟原子步骤 | `superpowers:writing-plans` | 实现计划（每步带验收标准） | 计划批准 |
| 4 执行 | 子代理三角色 + 强制 TDD + 两阶段 Review | `superpowers:subagent-driven-development` + `superpowers:test-driven-development` + `superpowers:requesting-code-review` | 通过审查的代码 + 测试 | spec 合规 ✓ 且 质量 ✓ |
| 5 归档 | 归档变更、更新规范 | `openspec-archive-change` → `openspec-sync-specs` | 更新后的 specs/ | changes 目录已归档 |

## 子代理三角色（执行阶段）

- **Implementer**：写码 + 写测试（TDD：先 RED 再 GREEN）
- **Spec Compliance Reviewer**：逐行对比 tasks.md / specs，是否按要求做了
- **Code Quality Reviewer**：spec 通过后才审命名 / 结构 / 复杂度 / 安全

> 顺序固定：先合规后质量。合规没过不审质量。这是用子代理专业分工替代「一人多职」的上下文切换。

## 执行步骤

1. 调 `openspec-propose`，输入需求 → 产出四件套 → **等用户确认** proposal
2. 调 `superpowers:brainstorming` → 一次一问、给 2-3 个带推荐的方案 → 涉及前端 UI 时生成独立 HTML 原型纳入 changes 目录
3. 设计批准后调 `superpowers:writing-plans` → 每个 step 是一个 2-5 分钟的动作
4. 调 `superpowers:subagent-driven-development` 执行：每个 task 内强制 `superpowers:test-driven-development`；task 完成后触发两阶段 Review（先 spec 合规，后 code quality）
5. 全部通过 + 完整性测试 → 调 `openspec-archive-change` 归档，再 `openspec-sync-specs` 同步规范

## 强制减速点（不可跳）

- 阶段 1 结束：proposal 必须有人确认
- 阶段 2：brainstorming 不许跳过（见 `sdd-gate` 误区一）
- 阶段 4：TDD + 两阶段 Review 不许省

## 全栈 UI 规范

design.md 涉及多页面 / 复杂交互时，纯文字不够 —— 让 Claude 生成 `openspec/changes/<变更名>/prototype.html`，作为「可执行 UI 规范」纳入版本管理。详见 `sdd-gate` 误区三。

## 备注

- 实际选型：无脑选 Subagent-Driven（阶段 4），除非任务仅 1-2 个简单 task、高度耦合需连续操作、或调试探索阶段。
- 这套流程可进一步固化成 cron / 命令；如需「新需求自动跑全闭环」，在本 skill 基础上包一层即可。
