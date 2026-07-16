---
name: sdd-flow
description: 开发请求自动分级（S1/S2/S3）与闭环编排入口，串联 OpenSpec 与 Superpowers 完成从规格到归档的全流程。
license: MIT
metadata:
  author: my-happy-coder
  version: "1.3.1"
  source: 据《Claude Code + OpenSpec + Superpowers 协同开发实践指南》提炼
---

# SDD 协同开发闭环（OpenSpec × Superpowers）

一句话：OpenSpec 管「做什么」，Superpowers 管「怎么做」，本 skill 把两者串成 `propose → brainstorm → plan → 子代理执行 → archive` 的可追溯闭环。

**触发词（含口语化措辞，命中任一即触发）**：实现/新增/增加/添加/修复/删除/重构/开发/修改/改动/调整/优化/完善/升级/更新/生成/搭建/创建/支持，口语「做个 X」「做一下」「加个」「加上」「改下」「改一下」「写个」「写一下」「弄/搞 X」；英文 build/add/create/update/change/modify/enhance/improve/support/fix/implement/refactor/delete/remove/bug/feat；以及「协同开发」「sdd flow」「完整流程」「从规格到归档」。口语化开发请求即使不含上述词也应触发（语义判定，偏保守触发）。查项目进度用 `sdd-progress`（触发词：项目进度/进度/现在在做什么/做到哪了）。

**分级输出强制（闸门可见产物，供 enforce 自检）**：被触发后必须先输出一行分级判定再做后续动作：`分级：S1|S2|S3 —— <一句理由>`。未输出分级即写码，视为跳过闸门，PreToolUse 自检会再次拦截。

## Step 0：分级闸门（自动，最先执行）

被触发后第一动作：读用户需求，按下表四信号打分，判定 S1 / S2 / S3。

| 信号 | S1 小 | S2 中 | S3 复杂 |
|---|---|---|---|
| 改动范围 | 1-2 文件、单包 | 单包多文件 | 跨包 / 架构级 |
| 决策含量 | 无（写法明确） | 小（1-2 选择） | 大（多方案，需 design） |
| 风险面 | 低 | 中 | 高（安全 / 数据模型 / 外部契约） |
| UI/交互 | 无或微调 | 单页面 | 多页面复杂交互 |

**升级规则：任一信号命中 S3 → 按 S3 走**（复杂度取最高项，非平均）。分级有歧义时偏保守（取高级别）。用户可强制覆盖（如「这个按 S3 走」）。

**bug 根因路由（分级前判）**：请求含「修复/fix/bug」且判定为 S2/S3 时，**写码前先跑 `superpowers:systematic-debugging`** 找根因，RCA 结果融入 design/plan 再进流程。直接 TDD 会测症状不测根因。S1 bug 不跑 RCA（小且明确，直接修 + TDD）。

**S2/S3 分支与工作区检查**（分级后、分支路由前执行，S1 豁免）：
- 执行 `git branch --show-current`，若为 `main` 或 `master`，提醒「⚠️ 当前在主干分支。S2/S3 变更请先 `git switch -c feat/<任务名>` 开新分支」
- 执行 `git status --porcelain`，有输出则提醒「⚠️ working tree 不干净，有未提交改动。建议先 `git stash` 或 commit 清理后再开始新变更」
- 两项检查通过后方可进入后续 S2/S3 流程

判定后**自动分支**：

- **S1 → 直接写 + 可选 E2E**：直接实现 + `superpowers:test-driven-development`（S1 bug 直接修，不跑 RCA）；非平凡逻辑留一个 `assert` 自检或小测试；不开 openspec、不跑 brainstorm、不跑 sdd-gate（S1 全自动，自检关卡在此为冗余）。TDD 完成后，主动询问用户是否需要追加端到端(E2E)测试。
- **S2 → 半闭环（减速点停）**：`openspec-propose` 出轻量 proposal + specs（design.md 可选）→ `superpowers:writing-plans` 拆几步 → `superpowers:test-driven-development` 执行（完成后询问用户是否追加E2E测试） → 跑一次 `sdd-gate` 自检五问 → **经验沉淀 + CHANGELOG 追加**（见「进度与经验沉淀」） → 不必 archive。减速点：proposal、plan 确认、是否进行E2E测试。
- **S3 → 全闭环（减速点停）**：走下方「S3 全闭环总览」五阶段。

## S3 全闭环总览（总览表，详细操作见「执行步骤」）

| 阶段 | 做什么 | 调用现有 skill | 产出 | 门禁 |
|---|---|---|---|---|
| 1 对齐 | 需求 → 结构化规格 | `openspec-propose` | proposal.md / design.md / specs/ / tasks.md | 用户确认 proposal |
| 2 头脑风暴 | 苏格拉底式追问、UI 可视化 | `superpowers:brainstorming` | 更新 design、可选 HTML 原型 | 设计批准 |
| 3 计划 | 拆 2-5 分钟原子步骤 | `superpowers:writing-plans` | 实现计划（每步带验收标准） | 计划批准 |
| 4 执行 | 子代理三角色 + 强制 TDD + 两阶段 Review + tasks.md 同步 | `superpowers:subagent-driven-development` + `superpowers:test-driven-development` + `superpowers:requesting-code-review` | 通过审查的代码 + 测试 + 已勾选 tasks.md | spec 合规 ✓ 且 质量 ✓ |
| 5 E2E + 归档 + 沉淀 | 强制 E2E → 最终验证 → 归档 → 经验蒸馏 + CHANGELOG | `superpowers:verification-before-completion` → `openspec-archive` → 经验捕获 | E2E 通过 + 已归档 + 经验入库 + CHANGELOG 追加 | E2E ✓ 且 verification ✓ 且 changes 已归档 |

## 子代理三角色（执行阶段）

- **Implementer**：写码 + 写测试（TDD：先 RED 再 GREEN）
- **Spec Compliance Reviewer**：逐行对比 tasks.md / specs，是否按要求做了
- **Code Quality Reviewer**：spec 通过后才审命名 / 结构 / 复杂度 / 安全

> 顺序固定：先合规后质量。合规没过不审质量。这是用子代理专业分工替代「一人多职」的上下文切换。

## 执行步骤（S3 详细操作）

1. 调 `openspec-propose`，输入需求 → 产出四件套 → **等用户确认** proposal
2. 调 `superpowers:brainstorming` → 一次一问、给 2-3 个带推荐的方案 → 涉及前端 UI 时生成独立 HTML 原型纳入 changes 目录
3. 设计批准后调 `superpowers:writing-plans` → 每个 step 是一个 2-5 分钟的动作
4. 调 `superpowers:subagent-driven-development` 执行：每个 task 内强制 `superpowers:test-driven-development`；**每个 task 完成（GREEN + review 过）即勾选 `openspec/changes/<变更名>/tasks.md` 对应项**（需求级进度实时同步，中断后可从此接续）；task 完成后触发两阶段 Review（先 spec 合规，后 code quality）。若执行中暴露多个**独立**故障（不同子系统/不同根因），可临时叠加 `superpowers:dispatching-parallel-agents` 并行排查（调试用，非常规执行手段）
5. 全部通过 + `superpowers:verification-before-completion` 最终验证 + 完整性测试（默认强制进行E2E端到端测试） → **archive 前确认 `git status --porcelain` clean 或改动已全部 commit** → 调 `openspec-archive` 归档 → **经验沉淀**（见下方「进度与经验沉淀」）

## 强制减速点（不可跳）

- 阶段 1 结束：proposal 必须有人确认
- 阶段 2：brainstorming 不许跳过（见 `sdd-gate` 误区一）
- 阶段 4：TDD + 两阶段 Review 不许省
- 阶段 5：E2E 端到端测试必须通过才能归档

## 失败处理路径

| 失败场景 | 处理方式 |
|---|---|
| TDD 测试失败（RED 无法 GREEN） | Implementer 子代理自行修复，连续 3 次失败后**停下来报告用户**，附上失败日志和分析 |
| Spec Compliance Review 未通过 | 返回 Implementer 修改，不进入 Code Quality Review；连续 2 轮不过则**停下确认** |
| Code Quality Review 未通过 | 返回 Implementer 修改；连续 2 轮不过则**停下确认** |
| E2E 测试失败 | **停下来报告用户**，附上失败的测试用例和错误信息，由用户决定是修复还是跳过 |
| 子代理卡死（连续多轮无进展） | **自动停下报告用户**，等同连续失败处理，附卡死的 task 名、当前状态和已尝试的方案 |

## 全栈 UI 规范

design.md 涉及多页面 / 复杂交互时，纯文字不够 —— 让 Claude 生成 `openspec/changes/<变更名>/prototype.html`，作为「可执行 UI 规范」纳入版本管理。详见 `sdd-gate` 误区三。

## 进度与经验沉淀（S2/S3 完成时执行）

**经验蒸馏（全自动，趁上下文热）**：

- **素材源**：本次变更的 TDD 失败处理记录、两阶段 review 发现、brainstorm 取舍决策、spec 偏差
- **动作**：蒸馏成结构化经验 `{ 场景, 教训(一句话), 触发条件, 相关文件 }`
- **存储（首选 claude-mem，降级 LESSONS.md）**：
  - 装了 `claude-mem` → 调 `claude-mem:save_memory`，`project` tag = 当前项目名（跨项目语义召回，下次自动浮出）
  - 未装 → 追加到项目 `openspec/LESSONS.md`，同样结构（项目内 fallback，并提示「装 claude-mem 可跨项目复用经验」）
- **S1 不蒸馏**：变更太小、经验密度低，且全自动不打断

**CHANGELOG 追加（项目根，只增不改）**：

- **位置**：项目根 `CHANGELOG.md`（有则追加，无则新建）
- **触发**：S2 完成（gate 后）、S3 archive 后，各追加一行
- **格式**：`- YYYY-MM-DD <变更名>: <一句话摘要> (S2|archived)`
- **作用**：纯历史轨迹，供 `sdd-progress` 读取「最近完成」段；与 sdd-progress（实时生成）职责正交

**需求级进度同步（S3 only）**：见执行步骤 4，每个 task 完成勾选 tasks.md。

## 备注

- 实际选型：S3 阶段 4 默认 `subagent-driven-development`；若任务仅 1-2 个简单 task、高度耦合需连续操作、或调试探索阶段，改用 `executing-plans` 轻量执行。
- 这套流程可进一步固化成 cron / 命令；如需「新需求自动跑全闭环」，在本 skill 基础上包一层即可。
- S2 流程末尾应**显式调用 `sdd-gate`** 自检五问（不依赖用户手动触发）。
