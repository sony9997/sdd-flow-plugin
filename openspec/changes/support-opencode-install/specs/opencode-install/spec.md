# opencode-install

## 概述
把 sdd-flow 三个 skill 安装到 OpenCode 原生扫描路径（`~/.claude/skills/` 或 env 覆盖），使其被 OpenCode skill 工具发现并可加载；提供软闸门规则片段替代 Claude 声明式 hook。

## 行为规格

### 功能 1：install 脚本分发
- 输入：仓库 `skills/<name>/SKILL.md`（name ∈ {sdd-flow, sdd-gate, sdd-progress}），可选 `SDD_INSTALL_DIR` 环境变量
- 处理：默认目标 `$HOME/.claude/skills`；逐 skill 校验 frontmatter `name`==目录名后 `cp -R` 覆盖到 `$DEST/<name>/`
- 输出：stdout 列出已安装 skill 名 + 生效提示；退出码 0
- 边界：目标目录不存在则创建；重复运行幂等覆盖；name 不匹配则跳过该 skill 并 stderr 告警

### 功能 2：verify 脚本自检
- 输入：同上 DEST
- 处理：三 skill 均存在、`name` 匹配目录、description 非空（1-1024 字符）
- 输出：逐项 PASS/FAIL；全过退出 0，任一 FAIL 退出 1

### 功能 3：软闸门规则片段
- 输入：`docs/opencode-rules.md`
- 处理：提供 AGENTS.md 片段，语义复刻「开发类请求先 invoke sdd-flow 做 S1/S2/S3 分级」
- 输出：可粘贴文本，含分级输出格式要求

## 验收场景

### 场景 1：全新安装（正常流程）
Given: 目标机无 `~/.claude/skills/sdd-flow`
When: 运行 `scripts/install-opencode.sh`
Then: `~/.claude/skills/{sdd-flow,sdd-gate,sdd-progress}/SKILL.md` 均存在；脚本退出 0；stdout 列出三个 skill

### 场景 2：幂等重装
Given: `~/.claude/skills/sdd-flow` 已存在（旧版本）
When: 再次运行 install
Then: 覆盖为最新内容；退出 0；无报错

### 场景 3：自定义目标
Given: 设 `SDD_INSTALL_DIR=/tmp/oc-skills`
When: 运行 install
Then: 三 skill 落到 `/tmp/oc-skills/<name>/`；verify 针对该路径通过

### 场景 4：name 不匹配防护
Given: 某 skill 的 frontmatter `name` 与目录名不符（人为构造）
When: 运行 install
Then: 该 skill 被 stderr 告警并跳过；其余正常；退出码非 0（提示修复）

### 场景 5：OpenCode 实际发现（端到端）
Given: install 成功
When: 启动 OpenCode 新会话
Then: skill tool 描述中列出 sdd-flow/sdd-gate/sdd-progress；可按触发词加载

### 场景 6：软闸门降级（异常/降级流程）
Given: OpenCode 无 Claude 声明式 hook
When: 用户粘贴 `docs/opencode-rules.md` 片段到 AGENTS.md
Then: 开发类请求时模型被规则文本引导先做分级（软提醒，依赖模型自觉，非硬阻断）

## 非功能性要求
- 脚本 POSIX sh 兼容（dash/bash/zsh 均可），无 bashism
- 无外部依赖（不依赖 jq/yq；frontmatter 解析用 grep/sed）
- 幂等、可重复、退出码语义清晰
