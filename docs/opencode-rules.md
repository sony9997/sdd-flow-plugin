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
