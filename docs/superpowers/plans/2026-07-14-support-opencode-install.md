# support-opencode-install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 sdd-flow 的三个 skill 可安装到 OpenCode 扫描路径并被发现，软闸门规则片段替代 Claude 声明式 hook。

**Architecture:** 复用 OpenCode 对 `.claude/skills/*/SKILL.md` 的原生扫描。install 脚本幂等拷贝仓库 `skills/` → `~/.claude/skills/`（双工具兼容）；hook 软提醒降级为 AGENTS.md 文本片段。skills 内容零改动。

**Tech Stack:** POSIX sh（无 bashism，无 jq/yq），grep/sed 解析 frontmatter，shell 测试脚本作 TDD。

## Global Constraints

- 脚本 POSIX sh 兼容（dash/bash/zsh），无 bashism（无 `[[`、数组、`local` 语义依赖）。
- 无外部依赖：frontmatter 用 `grep`+`sed` 解析，禁 jq/yq。
- 幂等：重复运行覆盖不报错；退出码语义清晰（全成功 0，有跳过/校验失败 1）。
- skill frontmatter `name` 必须等于目录名（OpenCode 硬性要求，不符则忽略该 skill）。
- Claude Code 侧（`.claude-plugin/`、`hooks/sdd-hooks.json`）不动。
- commit 无 attribution（用户全局禁用）。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `scripts/install-opencode.sh` | 幂等拷 skills → DEST，name 校验 | Create |
| `scripts/verify-opencode.sh` | 自检落位/name/description，退出码 0/1 | Create |
| `tests/test_install_opencode.sh` | install 行为测试（临时 DEST） | Create |
| `tests/test_verify_opencode.sh` | verify 行为测试 | Create |
| `docs/opencode-rules.md` | AGENTS.md 软闸门片段 | Create |
| `README.md` | 新增「在 OpenCode 中安装」章节 | Modify（line 36-38 之间插入） |

---

## Task 1: install 脚本（TDD）

**Files:**
- Create: `scripts/install-opencode.sh`
- Test: `tests/test_install_opencode.sh`

**Interfaces:**
- Produces: `scripts/install-opencode.sh`，读 env `SDD_SOURCE_DIR`（默认 `$REPO/skills`）与 `SDD_INSTALL_DIR`（默认 `$HOME/.claude/skills`）；退出码 0=全成功，1=有跳过/校验失败。

- [ ] **Step 1: 写失败测试**

Create `tests/test_install_opencode.sh`:

```sh
#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export SDD_INSTALL_DIR="$TMP/skills"

fail() { echo "FAIL: $1" >&2; exit 1; }

# scenario 1: three skills land + name matches dir
sh "$ROOT/scripts/install-opencode.sh" >/tmp/oc_install.log 2>&1 || fail "install exited non-zero on clean run"
for s in sdd-flow sdd-gate sdd-progress; do
  [ -f "$TMP/skills/$s/SKILL.md" ] || fail "missing $s/SKILL.md"
done

# scenario 2: idempotent rerun
sh "$ROOT/scripts/install-opencode.sh" >/dev/null 2>&1 || fail "rerun not idempotent"

# scenario 3: name mismatch in injected source -> skipped + non-zero exit
BAD="$TMP/badsrc/badname"
mkdir -p "$BAD"
printf -- '---\nname: wrong\ndescription: x\n---\nbody\n' > "$BAD/SKILL.md"
SDD_SOURCE_DIR="$TMP/badsrc" SDD_INSTALL_DIR="$TMP/baddest" \
  sh "$ROOT/scripts/install-opencode.sh" >/tmp/oc_bad.log 2>&1 && fail "bad name should exit non-zero"
[ -d "$TMP/baddest/wrong" ] && fail "mismatched skill should not be copied"
[ -d "$TMP/baddest/badname" ] && fail "mismatched skill dir should not be created"

echo "test_install_opencode PASS"
```

- [ ] **Step 2: 运行测试确认失败**

Run: `sh tests/test_install_opencode.sh`
Expected: FAIL（`scripts/install-opencode.sh` 不存在）。

- [ ] **Step 3: 写实现**

Create `scripts/install-opencode.sh`:

```sh
#!/bin/sh
# Install sdd-flow skills into an OpenCode-scanned path (default ~/.claude/skills).
# Idempotent. Exits 0 if all skills installed, 1 if any skipped/validated-fail.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC="${SDD_SOURCE_DIR:-$ROOT/skills}"
DEST="${SDD_INSTALL_DIR:-$HOME/.claude/skills}"

[ -d "$SRC" ] || { echo "ERROR: source skills dir not found: $SRC" >&2; exit 1; }
mkdir -p "$DEST"

rc=0
count=0
for skill_dir in "$SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    echo "WARN: $name has no SKILL.md, skip" >&2
    rc=1
    continue
  fi
  fm_name=$(grep -m1 '^name:' "$skill_md" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$fm_name" != "$name" ]; then
    echo "ERROR: $name: frontmatter name '$fm_name' != dir name, skip (OpenCode requires match)" >&2
    rc=1
    continue
  fi
  mkdir -p "$DEST/$name"
  cp -R "$skill_dir/." "$DEST/$name/"
  echo "installed: $name -> $DEST/$name"
  count=$((count + 1))
done

echo "done: $count skill(s) -> $DEST"
echo "restart OpenCode (or open a new session) for skills to be discovered"
exit "$rc"
```

- [ ] **Step 4: 运行测试确认通过**

Run: `sh tests/test_install_opencode.sh`
Expected: `test_install_opencode PASS`

- [ ] **Step 5: chmod + commit**

```bash
chmod +x scripts/install-opencode.sh
git add scripts/install-opencode.sh tests/test_install_opencode.sh
git commit -m "feat: add install-opencode.sh to distribute skills to OpenCode scan path"
```

---

## Task 2: verify 脚本（TDD）

**Files:**
- Create: `scripts/verify-opencode.sh`
- Test: `tests/test_verify_opencode.sh`

**Interfaces:**
- Consumes: install 产出的 `$DEST/<name>/SKILL.md`（Task 1）。
- Produces: `scripts/verify-opencode.sh`，读 env `SDD_INSTALL_DIR`（默认 `$HOME/.claude/skills`）；逐 skill PASS/FAIL，全过退出 0，任一 FAIL 退出 1。

- [ ] **Step 1: 写失败测试**

Create `tests/test_verify_opencode.sh`:

```sh
#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DEST="$TMP/skills"
export SDD_INSTALL_DIR="$DEST"

fail() { echo "FAIL: $1" >&2; exit 1; }

# scenario 1: installed -> verify exits 0
sh "$ROOT/scripts/install-opencode.sh" >/dev/null 2>&1 || fail "install failed"
sh "$ROOT/scripts/verify-opencode.sh" >/dev/null 2>&1 || fail "verify should pass after install"

# scenario 2: remove one skill -> verify exits 1
rm -rf "$DEST/sdd-gate"
sh "$ROOT/scripts/verify-opencode.sh" >/tmp/oc_v.log 2>&1 && fail "verify should fail when skill missing"

echo "test_verify_opencode PASS"
```

- [ ] **Step 2: 运行测试确认失败**

Run: `sh tests/test_verify_opencode.sh`
Expected: FAIL（`scripts/verify-opencode.sh` 不存在）。

- [ ] **Step 3: 写实现**

Create `scripts/verify-opencode.sh`:

```sh
#!/bin/sh
# Verify sdd-flow skills are installed and OpenCode-discoverable at DEST.
set -u
DEST="${SDD_INSTALL_DIR:-$HOME/.claude/skills}"
rc=0
for s in sdd-flow sdd-gate sdd-progress; do
  f="$DEST/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "FAIL: $s missing at $f" >&2
    rc=1
    continue
  fi
  fm=$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$fm" != "$s" ]; then
    echo "FAIL: $s frontmatter name '$fm' != '$s'" >&2
    rc=1
    continue
  fi
  desc=$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//')
  if [ -z "$desc" ]; then
    echo "FAIL: $s description empty" >&2
    rc=1
    continue
  fi
  echo "PASS: $s"
done
exit "$rc"
```

- [ ] **Step 4: 运行测试确认通过**

Run: `sh tests/test_verify_opencode.sh`
Expected: `test_verify_opencode PASS`

- [ ] **Step 5: chmod + commit**

```bash
chmod +x scripts/verify-opencode.sh
git add scripts/verify-opencode.sh tests/test_verify_opencode.sh
git commit -m "feat: add verify-opencode.sh self-check for skill discoverability"
```

---

## Task 3: 软闸门规则片段

**Files:**
- Create: `docs/opencode-rules.md`

**Interfaces:** 无（独立文档）。语义复刻 `hooks/sdd-hooks.json` 的 UserPromptSubmit 分级提醒 + PreToolUse 写码自检。

- [ ] **Step 1: 写文档**

Create `docs/opencode-rules.md`:

````markdown
# OpenCode 软闸门规则片段

OpenCode 无 Claude 声明式 hook，但支持 `AGENTS.md`（项目级）与全局规则。把下方片段粘进项目根 `AGENTS.md`（或 `~/.config/opencode/` 全局规则），即可在 OpenCode 中复刻 sdd-flow 的分级软闸门。**软提醒**：靠模型自觉，非硬阻断（与 Claude 侧 printf hook 同质）。

## 片段（粘进 AGENTS.md）

```markdown
## SDD Flow 分级闸门（sdd-flow）

收到疑似开发类请求（含 实现/新增/增加/添加/修复/删除/重构/开发/修改/优化/升级/创建/支持，或 build/add/create/update/fix/implement/refactor/delete/bug/feat，或口语「做个/加个/改下/写个/搞」）时：

1. 第一步必须 invoke `sdd-flow` skill 做 S1/S2/S3 分级。
2. 判级须显式输出一行：`分级：S1|S2|S3 —— <一句理由>`。
3. 未输出分级即写码，视为跳过闸门——停下先 invoke sdd-flow。
4. S1 直接写+TDD；S2 走 openspec-propose；S3 全闭环。

写码动作（编辑/创建文件）前自检：本会话已 invoke sdd-flow 并输出分级？未分级则停下先 invoke。S1 可继续，S2/S3 须按路径走。
```

## 说明

- 非开发类请求（查信息/读代码/闲聊）忽略本闸门。
- 触发可靠性低于 Claude 侧硬 matcher hook（~85% vs ~98%），因依赖模型读规则自觉。
- sdd-flow/sdd-gate/sdd-progress 三个 skill 的 description 已含触发词，OpenCode skill 工具会按语义召回，双保险。
````

- [ ] **Step 2: 校验内容存在关键标记 + commit**

Run: `grep -c '分级' docs/opencode-rules.md`（Expected: ≥3）
Run: `grep -c 'AGENTS.md' docs/opencode-rules.md`（Expected: ≥2）

```bash
git add docs/opencode-rules.md
git commit -m "docs: add opencode soft-gate rules snippet (AGENTS.md) to replace declarative hooks"
```

---

## Task 4: README「在 OpenCode 中安装」章节

**Files:**
- Modify: `README.md`（在 line 36 ``` 之后、line 38 `## 升级` 之前插入新章节）

- [ ] **Step 1: 插入章节**

在 `README.md` 的 Claude Code 安装代码块（`/plugin install sdd-flow@sdd-flow` + 结束 ```，约 line 36）之后、`## 升级`（line 38）之前，插入：

```markdown
## 在 OpenCode 中安装

[OpenCode](https://opencode.ai) 原生兼容 Claude 的 `SKILL.md` 格式（扫描 `~/.claude/skills/`、`.claude/skills/`、`.opencode/skills/`），三个 skill 内容零改动即可被发现。

一键安装（拷到 `~/.claude/skills/`，OpenCode 与 Claude Code 用户级双兼容）：

```bash
git clone https://github.com/sony9997/sdd-flow-plugin.git
cd sdd-flow-plugin
./scripts/install-opencode.sh
./scripts/verify-opencode.sh   # 自检三 skill 落位 + name 匹配
```

自定义目标（如项目级 `.opencode/skills/`）：

```bash
SDD_INSTALL_DIR=./.opencode/skills ./scripts/install-opencode.sh
```

重启 OpenCode 或开新会话后，sdd-flow/sdd-gate/sdd-progress 出现在 skill 工具列表。

### 软闸门（替代 Claude hook）

OpenCode 无声明式 hook。把 `docs/opencode-rules.md` 的片段粘进项目 `AGENTS.md`，复刻分级软闸门（软提醒，靠模型自觉，可靠性 ~85%，低于 Claude 侧硬 matcher 的 ~98%）。

### 前置依赖

同 Claude 侧：OpenSpec（`openspec-propose`/`openspec-archive`）、Superpowers（`brainstorming`/`writing-plans`/`test-driven-development` 等）需按各自官方方式安装到 OpenCode。本套件只含编排层。
```

- [ ] **Step 2: 校验章节已插入 + commit**

Run: `grep -c '在 OpenCode 中安装' README.md`（Expected: 1）
Run: `grep -c 'install-opencode.sh' README.md`（Expected: ≥2）

```bash
git add README.md
git commit -m "docs: add OpenCode install section to README"
```

---

## Task 5: 端到端验收 + S2 收尾

**Files:**
- Create: `CHANGELOG.md`（项目根，S2 完成追加）
- Modify: `openspec/changes/support-opencode-install/tasks.md`（勾选已完成项）

- [ ] **Step 1: 跑全部测试**

Run: `sh tests/test_install_opencode.sh && sh tests/test_verify_opencode.sh`
Expected: 两行 `... PASS`，退出 0。

- [ ] **Step 2: 临时 DEST 端到端（spec 场景 1/3）**

Run:
```bash
TMP=$(mktemp -d)
SDD_INSTALL_DIR="$TMP/skills" ./scripts/install-opencode.sh
SDD_INSTALL_DIR="$TMP/skills" ./scripts/verify-opencode.sh && echo "E2E GREEN"
rm -rf "$TMP"
```
Expected: 输出三 skill installed + 三 PASS + `E2E GREEN`，退出 0。

- [ ] **Step 3: 勾选 tasks.md**

把 `openspec/changes/support-opencode-install/tasks.md` 中 Task 1-4 全部勾选（`- [ ]` → `- [x]`），Task 5 验收项除「OpenCode 会话内确认」（需手动真实环境）外勾选。

- [ ] **Step 4: 建 CHANGELOG + commit**

Create `CHANGELOG.md`:

```markdown
# Changelog

- 2026-07-14 support-opencode-install: sdd-flow skills 可安装到 OpenCode 扫描路径，软闸门规则片段替代声明式 hook (S2)
```

```bash
git add CHANGELOG.md openspec/changes/support-opencode-install/tasks.md
git commit -m "chore: add CHANGELOG, mark support-opencode-install tasks done"
```

- [ ] **Step 5: sdd-gate 自检 + 经验沉淀**

跑 `sdd-gate` skill 五/六问自检（spec 合规、未跳 brainstorm 类比、E2E、进度/经验更新）。经验蒸馏存 claude-mem（`save_memory`，project=sdd-flow-plugin）或降级 `openspec/LESSONS.md`。

---

## Self-Review

**Spec coverage:** spec 场景 1（全新安装）→ Task 1 test + Task 5 step2；场景 2（幂等）→ Task 1 test scenario 2；场景 3（自定义目标）→ Task 5 step2 + env；场景 4（name 不匹配防护）→ Task 1 test scenario 3；场景 5（OpenCode 实际发现）→ Task 5 step5 手动（真实环境，标注）；场景 6（软闸门降级）→ Task 3。全覆盖。

**Placeholder scan:** 无 TBD/TODO，所有代码 step 含完整代码。

**Type/signature consistency:** env 名统一 `SDD_INSTALL_DIR`/`SDD_SOURCE_DIR`，skill 名 sdd-flow/sdd-gate/sdd-progress 全文一致，退出码语义（0 全过 / 1 有失败）全文一致。
