---
name: sdd-gate
description: SDD 协同开发避坑守门员 —— 检查四大误区（绕过 Superpowers 直接写码 / 混淆 OpenSpec specs 与 Superpowers plans / 全栈 UI 只靠纯文字 / 跳过 E2E 只跑单元测试）。在任何开发阶段都可调用，强制减速对齐。触发词：「避坑」「sdd gate」「检查误区」「跳过了 brainstorm」「specs 和 plans 分不清」「UI 怎么描述」「E2E 要不要跑」。
license: MIT
metadata:
  author: my-happy-coder
  version: "1.3.0"
  source: 据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼
---

# SDD 避坑守门员

四大误区检查。任何阶段都可调，发现「正在踩坑」就拦下。

触发词：避坑、sdd gate、检查误区、跳过了 brainstorm、specs 和 plans 分不清、UI 怎么描述、E2E 要不要跑

## 误区一：绕过 Superpowers 直接写代码

- **症状**：用户说「跳过 brainstorming 直接写」「别问了直接做」
- **为什么错**：brainstorming 是有意的「减速」。短期省几分钟，返工 + bug 修复时间数倍于节省
- **守门动作**：暂停，提醒「这是有意减速」，至少做一轮 `superpowers:brainstorming` 再进 plan。若用户坚持，记一句备注后放行，但显式 flag 风险
- **分级豁免**：此规则仅适用于 S2/S3。S1 级按设计不跑 brainstorm，不视为误区

## 误区二：混淆 OpenSpec specs 与 Superpowers plans

- **症状**：把执行步骤写进 `specs/`，或把 specs 当 plan 用
- **区分**：
  - OpenSpec `specs/` = **静态行为**（API 定义、数据模型、验收场景）——「正确的目标」
  - Superpowers plans = **动态执行步骤**（先做啥、每步验收标准）——「到达目标的路径」
- **关系**：上下游，不是替代。前者定义「是什么」，后者规划「怎么做」
- **守门动作**：阶段 3 写 plan 前确认 `specs/` 已存在且稳定；plan 里只写「怎么做」，不重复定义「是什么」

## 误区三：全栈项目 design.md 只写纯文字

- **症状**：前端多页面 / 复杂交互，design.md 全是文字 → AI 理解偏差，实现出来的界面和预期差很远，返工成本甚至高于后端
- **守门动作**：design 涉及 UI 时，生成独立 HTML 原型文件作为「可执行 UI 规范」：
  - 路径：`openspec/changes/<变更名>/prototype.html`（随变更目录统一版本管理）
  - 作用：给 Claude 的 UI ground truth，比文字描述精确得多
  - 预览：本地直接打开，或用项目现有预览途径（如 `pnpm --filter happy-app web`）
- **判定**：单页面 / 无复杂交互 → 文字够；多页面 / 复杂状态 → 必须出 HTML 原型

## 误区四：跳过 E2E 只跑单元测试

- **症状**：代码写完只跑单元测试就标记完成，不验证用户真实路径
- **为什么错**：单元测试只覆盖孤立函数/模块，跨模块集成、真实用户操作路径的缺陷漏网。上线后才发现的集成 bug 修复成本远高于提前 E2E
- **守门动作**：实现完成后评估是否需要 E2E：
  - S3：强制执行 E2E，不可跳过
  - S2：主动询问用户是否追加 E2E
  - S1：主动询问用户是否追加 E2E
- **判定**：纯工具函数/无外部依赖 → 单元测试够；涉及 API 调用/多页面跳转/外部服务 → 必须跑 E2E

## 自检七问（任一阶段结束前）

> 注意：执行自检时先确认当前任务的分级（S1/S2/S3），部分检查项仅适用于特定分级。

1. 我跳过 brainstorm / TDD / review 了吗？（→ 误区一，仅 S2/S3）
2. 我的 plan 在重复 specs 已有的「是什么」吗？（→ 误区二）
3. 这块 UI 我只用文字描述了吗？（→ 误区三）
4. 应该跑 E2E 的场景是否已进行/已询问？（→ 误区四，S1/S2 询问，S3 强制）
5. 实现与 spec 是否一致？（对照 tasks.md / specs 逐项核对）
6. 进度与经验是否已更新？（S3：tasks.md 已勾选；S2/S3：经验已蒸馏 + CHANGELOG 已追加）
7. archive/CHANGELOG 追加前 git status clean？（S2/S3，改动已全部 commit？）

全否 → 放行；任一是 → 先修再走。
