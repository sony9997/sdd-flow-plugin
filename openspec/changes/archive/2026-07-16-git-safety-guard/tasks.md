# Implementation Tasks

## 1. git-guard.sh 守卫脚本
- [x] 1.1 创建 `hooks/git-guard.sh`：stdin JSON 解析 + 危险命令匹配 + exit 0/1（预估 30min）

## 2. hooks/sdd-hooks.json 修改
- [x] 2.1 PreToolUse 追加 Bash matcher → git-guard.sh（预估 10min）
- [x] 2.2 UserPromptSubmit 追加 main 分支检查命令（预估 10min）
- [x] 2.3 新增 Stop hook：dirty tree 提醒（预估 10min）

## 3. sdd-flow SKILL.md 修改
- [x] 3.1 Step 0 追加 S2/S3 分支 + dirty 检查指令（预估 15min）
- [x] 3.2 S3 阶段 5 追加 archive 前 clean 检查指令（预估 10min）

## 4. sdd-gate SKILL.md 修改
- [x] 4.1 自检七问追加 git clean 检查项（预估 5min）

## 5. 验证
- [x] 5.1 手动测试 git-guard.sh：mock stdin JSON 覆盖 6 种场景（预估 20min）
- [x] 5.2 集成验证通过：6/6 pass + sdd-hooks.json 结构正确

## 6. CHANGELOG
- [x] 6.1 追加 CHANGELOG 条目（预估 5min）
