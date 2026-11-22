---
name: agent-relay
description: 多 Agent / 多会话在同一 Git 仓库接力完成任务的协作协议。当用户要求「多 agent 协作」「接力 / 交接任务 / 派单 / 接手 / 跨会话继续项目」，或需要在同一工作区（含同一会话内换模型）把大任务拆成可验收小卡并跨执行者传递时使用。单 agent 一次性小任务不要触发。
agent_created: true
---

# Agent Relay · 多 Agent 接力协议

## 目的

让多个独立 Agent（不同机器、不同客户端、同一工作区的不同会话、甚至同一会话内换模型）在**同一个 Git 远端**上接力完成任务。共享记忆不是聊天窗口，也不是本地目录，而是已推送的提交、任务卡、交接单和状态文件。

## 加载后立即执行的 3 步

1. 确认当前目录是目标仓库根目录（`git rev-parse --show-toplevel`）；若不是，先切换过去。
2. 运行 `bash <skill-dir>/scripts/relay-sync.sh <TASK_ID>`（未提供 TASK_ID 时只读 `git fetch --all --prune` 与 `git branch -a`）。
3. 读取 `.agent/state.json` → `.agent/handoffs/<TASK_ID>.md` → `git log --oneline -3`，输出三行结论：**现状 / 要改的文件 / 风险**，再决定动作。绝不跳过这一步直接改代码。

## 五条核心原则

- **P1 远端才是共享内存**：没 push 的改动在下一棒眼里不存在。
- **P2 接力单位是一张卡 + 一个分支 + 一次绿色提交**：不是「聊完换人」，是做完可验收的增量再换人。
- **P3 一卡一分支，main 只接受合并**：远程分支存在即视为认领。
- **P4 交接标准是对方 fetch 一次就能继续**：交接单必须随代码推到远端。
- **P5 换模型也是交接，落盘才算数**：同会话换模型没有会话结束断点，必须显式打检查点（见「软交接」）。

## 动作决策

- 任务还没有卡 → 派单：用 `assets/task-card.md` 生成 `.agent/tasks/<TASK_ID>.md`，写死一个可验收目标、验收命令、allowed_paths、禁止事项，推到远端。
- 远程没有 `agent/<TASK_ID>` 分支 → 认领：`relay-claim.sh <TASK_ID>`（从最新 main 切分支 + push -u + 写 state）。
- 远程已有同名分支 → **续棒**，不要新建分支或复制卡：`git switch agent/<TASK_ID> && git pull --ff-only`，接着上一棒做；剩余部分能独立验收才拆新卡。
- 方向错了或卡不成立 → 废卡：分支打 tag 留档、不合并，写一句话原因，从 main 重新开卡。
- 当前是同会话换模型 → 走「软交接」，不换分支、不换卡。

## 标准工作流（七步）

| 步骤 | 执行者 | 动作与脚本 |
| --- | --- | --- |
| 01 派单 | 产品席 + 人 | 任务卡写入 `.agent/tasks/` 并 push；卡片不写「优化体验」，写验收命令 |
| 02 同步 | 任一席 | `relay-sync.sh`；看 origin 上已有哪几张卡 |
| 03 认领 | 实现席 | `relay-claim.sh <TASK_ID>`；push 成功才算占到 |
| 04 勘察 | 实现席 | 只读 AGENTS.md、交接单、源码、最近提交；先给 3 行结论，确认后再动手 |
| 05 实现 | 实现席 | 改动只落在 allowed_paths；build/test/lint 在自己克隆跑绿 |
| 06 交接 | 实现席 | `relay-verify.sh <TASK_ID>` 全过 → `relay-handoff.sh <TASK_ID>`；交接单与代码同一次 push |
| 07 评审合并 | 评审席 + 人 | 基于远端 diff 评审；`relay-merge.sh <TASK_ID>` 做 rebase + `--no-ff` 合并 |

最少两人即可跑通；席位越多交接越重，按最小可行编队起步。角色抽象与编队见 `references/roles.md`。

## 软交接：同一会话内换模型

换模型不是换会话，没有天然断点，因此**不换分支、不换任务卡，但必须打检查点**：

1. 换模型前：`relay-checkpoint.sh <TASK_ID> switch <NEW_MODEL>`。脚本负责 commit + push 当前改动、写 `state.session`（`handoff_kind=model_switch` / `checkpoint_commit` / `pending_model` / `model_history`）、生成检查点交接单并打印 `⟪RELAY-CHECKPOINT⟫` 分界线。
2. 新模型**第一个动作**：读 `state.json` → 检查点交接单 → `git log -1`，逐条复述约束重述四行（allowed_paths / 验收命令 / DoD / 当前 status）。聊天记录只作背景；与仓库冲突时以仓库为准。
3. 复述无误后：`relay-checkpoint.sh <TASK_ID> rebind`，把 `session.model` 写成新模型并留审计日志。
4. 新模型窗口更小或没有终端/push 能力时：先把长聊天压成交接单，必要时开新会话转硬交接；无写权的模型降为顾问席，只出卡和评审，写权交回有终端的会话。

规则全文与止损表见 `references/single-workspace.md`。

## 硬交接：换会话 / 换席位

WIP 交接单五格：现状 / 已完成（到提交号）/ 卡在哪（贴原始报错）/ 下一动作（只写一个可执行动作）/ 不要碰（文件 + 原因）。换棒三步：先把半成品 commit + push → 接手方 fetch + switch + pull + `git log -3` → 收口照常回主干。**禁止**用 stash、聊天粘贴或本地草稿交接。详见 `references/workshop.md`。

## 门与止损（简版）

- DoD 六条：构建、测试、lint 全绿且是本次改动后跑的；改动范围 = 卡范围；分支与交接单已推送；无密钥、无调试残留。`relay-verify.sh` 自动校验，未过不许写 `status=handoff`。
- 人工介入：`verify_fail ≥ 3` / 写不出验收命令 / 涉及生产凭据或数据迁移 / 同文件冲突无法裁决 → 写 `status=blocked` 并 @人。
- 反模式（出现即停写）：把本地目录当共享盘、直推 main、交接单只在本地、聊天粘贴当交接、一张卡塞一整个功能、跳过验收门换人。统一止损：**停写 → 回滚到上次绿色提交 → 补齐任务卡 → 重新派单**。
- 护栏 G1/G2/G3、信号处置表、协议版本兼容见 `references/guardrails.md`；状态机与 schema 见 `references/state-schema.md`。

## 资源索引

| 资源 | 何时读取 |
| --- | --- |
| `references/core-principles.md` | 需要理解 P1–P5 与单工作区适配的取舍 |
| `references/workshop.md` | 需要完整七步循环、换棒命令、仓库结构、五条前提 |
| `references/roles.md` | 派席位、选编队、查能力矩阵（产品名只是当前示例） |
| `references/guardrails.md` | 验收门、失败回滚、反模式、信号处置、人工介入阈值 |
| `references/templates.md` | 写任务卡、交接单、提交信息、派单/接手 Prompt（含 frontmatter） |
| `references/state-schema.md` | state.json 字段、状态机、log 事件、版本兼容 |
| `references/single-workspace.md` | 同会话换模型 / 单工作区模拟接力的完整规则 |
| `scripts/relay-*.sh` | 确定性动作，直接执行，不必先读进上下文；用 `--help` 看用法 |
| `assets/*.md`、`assets/state.example.json` | 新建任务卡 / 交接单 / 检查点交接单 / state 时复制后填写 |

## 脚本清单

`relay-init.sh`（初始化仓库协议骨架）· `relay-claim.sh`（认领）· `relay-sync.sh`（只读同步）· `relay-verify.sh`（DoD 自动校验）· `relay-handoff.sh`（写 handoff 并 push）· `relay-merge.sh`（rebase + no-ff 合并）· `relay-checkpoint.sh`（软交接 switch / rebind）。所有脚本从目标仓库根目录运行，入参统一 `TASK_ID`（形如 `T-014`）。执行前确认远端可访问；任何 push 被拒都先 fetch + rebase，禁止 force push。
