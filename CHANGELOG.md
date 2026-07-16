# Changelog

- 2026-07-16 git-safety-guard: 四层 git 安全约束（硬拒绝 merge 到主干+push / 软提醒分支+dirty / Stop hook 未提交提醒 / skill 层分支+clean 检查） (S2)
- 2026-07-14 support-opencode-install: sdd-flow skills 可安装到 OpenCode 扫描路径，软闸门规则片段替代声明式 hook (S2)
- 2026-07-14 support-opencode-install: install/verify 默认路径改 ~/.config/opencode/skills（OpenCode 原生全局；原 ~/.claude/skills 为兼容路径，仍可经 SDD_INSTALL_DIR 覆盖）(S1)
