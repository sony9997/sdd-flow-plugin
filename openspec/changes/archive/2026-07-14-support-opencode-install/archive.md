# 归档记录

## 基本信息
- **变更名称**：support-opencode-install
- **归档日期**：2026-07-14
- **负责人**：sony9997
- **分级路径**：S2（半闭环）→ S1 修正（默认路径）

## 变更摘要
让 sdd-flow 插件可安装到 OpenCode（opencode.ai）。利用 OpenCode 对 `.claude/skills/*/SKILL.md` 的原生扫描，三个 skill（sdd-flow/sdd-gate/sdd-progress）内容零改动分发到 OpenCode 扫描路径；声明式 hook（软提醒）降级为 AGENTS.md 文本片段。

## 关键决策
1. **分发 = install 脚本单源拷贝**，非仓库镜像（避免双份腐化）、非软链（跨平台脆弱）。
2. **默认路径 = `~/.config/opencode/skills/`**（OpenCode 原生全局）。初版误选 `~/.claude/skills/`（图 Claude 兼容，YAGNI），S1 修正——脚本名 install-**opencode** 即意图。
3. **hooks 软闸门降级**，非写 TS plugin。sdd-hooks.json 实测是 printf 软提醒（靠模型自觉），OpenCode event 无 prompt-submit 等价物；软提醒→AGENTS.md 文本行为等价，不值得 TS 工程。
4. **skills 零改动**：OpenCode frontmatter 认 name+description，未知字段忽略；name 须匹配目录名（已满足）。

## 技术栈
- POSIX sh（无 bashism，无 jq/yq）
- grep/sed 解析 frontmatter
- shell 测试脚本（TDD，无 bats）

## 测试结果
- install 测试：4 场景（落位/name 匹配/幂等/坏 name 跳过/默认路径）PASS
- verify 测试：2 场景（install 后 0/删 skill 后 1）PASS
- 端到端：临时 DEST install+verify GREEN，覆盖 spec 场景 1/2/3/4/6

## 审查记录
- 路径：S2（未走 S3 subagent 两阶段 Review）
- 质量保证：TDD（RED→GREEN 每 commit）+ sdd-gate 五问自检全过
- 默认路径修正：S1 TDD（scenario 4 锁定 `~/.config/opencode/skills`）

## 已知问题
- spec 场景 5（真实 OpenCode 会话内 skill 出现在列表）未自动验证——需用户在装了 OpenCode 的环境手动确认。

## 后续优化建议
- 若 OpenCode 未来支持硬 prompt-submit event，可评估写 `.opencode/plugins/sdd-flow.ts` 把软闸门升级为硬触发。
- 若多用户反馈全局/项目级混淆，可加 `--target global|project` 选项。

## 相关文件
- proposal.md / design.md / tasks.md / specs/opencode-install/spec.md
- 实现：`scripts/install-opencode.sh`、`scripts/verify-opencode.sh`、`tests/test_*.sh`、`docs/opencode-rules.md`、README「在 OpenCode 中安装」章节
- 实现计划：`docs/superpowers/plans/2026-07-14-support-opencode-install.md`
- 系统规范：`openspec/specs/opencode-install/spec.md`
