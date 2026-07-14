# Implementation Tasks

## 1. install 脚本
- [x] 1.1 写 `scripts/install-opencode.sh`：env 覆盖目标、遍历 skills/、name 校验、幂等拷贝、输出清单（~40min）
- [x] 1.2 本地 dry-run 验证：拷到临时 DEST，确认三 skill 落位（~15min）

## 2. verify 脚本
- [x] 2.1 写 `scripts/verify-opencode.sh`：检查落位 + name 匹配 + description 非空，退出码 0/1（~20min）

## 3. rules 片段
- [x] 3.1 写 `docs/opencode-rules.md`：AGENTS.md 软闸门片段 + 全局规则说明（~20min）

## 4. 文档
- [x] 4.1 README 新增「OpenCode 安装」章节：一键脚本 + 手动步骤 + 能力差异（软闸门 vs 硬提醒）+ 前置依赖（OpenSpec/Superpowers skills）（~25min）

## 5. 验收
- [x] 5.1 在真实 OpenCode 扫描路径跑 install + verify，绿（~15min）
- [ ] 5.2 OpenCode 会话内确认 sdd-flow skill 出现在 skill tool 列表（手动或截图）
- [x] 5.3 README 差异说明准确（软闸门不等于硬 hook）
