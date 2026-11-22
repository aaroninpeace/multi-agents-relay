# 单工作区多会话 / 同会话换模型

## 覆盖判定

「单工作区多会话」用**分支 + state.json + 交接单**替代目录隔离，能覆盖换会话 / 换席位的接力；它**不能直接覆盖**「同一 Agent、同一会话、前后使用不同模型」。

原因：

1. 多会话接力靠「会话结束」这个天然断点触发 commit + push + 交接单；换模型没有断点，未提交改动会被新模型就地继承。
2. 聊天记录仍留在窗口里，会跟仓库抢「唯一事实来源」的位置；新模型容易跳过 state.json，沿用上一模型的口头结论。
3. 上下文窗口、工具能力、指令遵循强度可能随模型变化，早期约束（allowed_paths / 验收命令 / DoD）会被静默截断。
4. 只记席位不记模型时，事后无法审计哪一棒由哪个模型完成。

因此：**机制可复用，但必须额外规定软交接**。

## 两种交接对照

| 维度 | 硬交接（换会话 / 换席位） | 软交接（同会话换模型） |
| --- | --- | --- |
| 触发时机 | 会话结束、任务转手、有人退出 | 会话中切换模型（含平台自动降级 / 升级） |
| 分支 / 任务卡 | 续棒或拆卡，owner 换席位 | **不换分支、不换卡**，task_id 与 status 原样保留 |
| 必做动作 | commit + push + 交接单 + state，下一棒 fetch 后从零读仓库 | commit + push + **检查点交接单** + state.session；新模型先读仓库再续做 |
| 事实来源 | 仓库 | **仓库优先**，聊天仅作背景；冲突以仓库为准 |
| 特有风险 | 没 push 等于没交接 | 聊天惯性、上下文截断、工具能力差异、模型身份不可审计 |

## 换模型前：落盘四件事

对应 `relay-checkpoint.sh <TASK_ID> switch <NEW_MODEL>`：

1. **把进度写成提交并推送**：当前改动全部 commit + push。聊天里说「改好了」不算；没 push 的改动在新模型眼里不存在。
2. **刷新 state.json 的 session 段**：写 `handoff_kind="model_switch"`、`checkpoint_commit`、`pending_model`、`updated_at`，向 `model_history` 追加旧模型及其截止提交。`owner` 仍写席位，`status` 不变。
3. **写检查点交接单**：沿用五格结构，额外补「约束重述」——allowed_paths、验收命令、DoD、当前 status 各一行。全文 ≤ 400 字，每条踩坑 ≤ 2 行；详细材料用链接指向仓库内文件。
4. **打出分界线**：输出 `⟪RELAY-CHECKPOINT: T-014 @ <commit> @ <旧模型> → <新模型>⟫`。它只是给人看的定位锚，**权威仍在仓库**，新模型不得把它当状态来源。

## 换模型后：先绑定，再动手

1. 新模型**第一个动作**：读 `state.json` → 检查点交接单 → `git log -1`，逐条复述「约束重述」四行。
2. 绝不直接沿用聊天里上一模型的口头结论。仓库与聊天冲突时以仓库为准，并在 `log.md` 记一条 `model_rebind_mismatch`。
3. 窗口变小：先把长聊天压成交接单；必要时开新会话转硬交接，不要让早期约束在新窗口里被静默截断。
4. 工具能力不同：新模型没有终端或不能 push 时，降级为顾问席（只出卡 / 评审），写权交回有终端的会话，按硬交接走。
5. 复述无误后运行 `relay-checkpoint.sh <TASK_ID> rebind`，把 `session.model` 写成新模型标识并清空 `pending_model`。若发现状态不一致，先写 `status=blocked` 并按人工介入阈值 @人。

## 三个高频坑与止损

| 坑 | 表现 | 止损动作 |
| --- | --- | --- |
| 聊天惯性 | 新模型把上一模型「我们决定这样改」当成已落盘事实，跳过 state.json | 强制先读仓库再动手；复述约束四行后才能改文件 |
| 上下文截断 | 小窗口模型继承长会话，allowed_paths / 验收命令在中部被丢掉 | 换模型前压交接单 + 重述约束；必要时转硬交接开新会话 |
| 身份不可审计 | 只记席位不记模型，事后分不清哪一棒是哪个模型做的 | `session.model_history` 逐次记录，log 事件带 model 字段 |

## 换席位但仍是单工作区

不换模型、只换执行者时按硬交接处理，但同样在同一目录里操作：

1. 先 commit + push 当前改动，再写交接单与 state；切角色前不留未推送文件。
2. 剩余工作可独立验收 → 原卡收口合并，从最新 main 开新卡；不可独立验收 → 续同一条分支，只追加提交。
3. 「commit + push 才算交接」在单工作区更重要：本地文件和聊天记录都还在原地，最容易让人误以为已经交接。

## 脚本支持

| 命令 | 作用 |
| --- | --- |
| `relay-checkpoint.sh <TASK_ID> switch <NEW_MODEL>` | 提交并推送当前改动 → 写检查点交接单 → 更新 state.session → 打印分界线 |
| `relay-checkpoint.sh <TASK_ID> rebind` | 校验 pending_model 与检查点文件 → 写入 session.model → 记录 model_rebind |
| `relay-verify.sh <TASK_ID>` | 校验 checkpoint_commit / checkpoint_handoff / last_commit 一致性 |

`relay-verify.sh` 在 `session.handoff_kind=model_switch` 时额外要求：检查点交接单存在、`checkpoint_commit` 与 state 一致且提交在远端分支上。
