# agent-relay

多 Agent / 多会话在**任意一个 Git 仓库**（GitHub / GitLab / Gitea / 自建 Git 皆可，不绑定特定仓库）接力完成任务的协作协议，以 **WorkBuddy 用户级 Skill** 形式交付。唯一要求是参与各方对同一个 `origin` 有 fetch / push 权限。协议手册 Human-readable 版本见 `docs/agent-relay-playbook.html`（V1.3）。

## 触发场景

用户说「多 agent 协作」「接力 / 交接任务」「派单 / 接手」「跨会话继续项目」，或需要在同一工作区把大任务拆成可验收小卡跨执行者传递时加载。单 agent 一次性小任务不要触发。

### 怎么用：什么场景发什么话

不用记特殊语法，用自然语言把「哪张卡 + 什么动作」说清楚即可。两种触发方式：

- **自动触发**：话里出现上面那些关键词，Skill 按 description 自动加载。
- **显式调用**：任意一轮直接输入 `/agent-relay` 再跟需求，强制加载（自动没命中时用这个）。

把「T-014」换成你自己的任务号（形如 `T-014`）。首次使用某个仓库时，先说一句「用 agent-relay 初始化这个仓库的接力骨架」跑 `relay-init`，之后按下面照抄：

| 场景 | 直接对 Agent 说（可照抄） | Skill 实际做的事 |
| --- | --- | --- |
| 开卡派单 | 「用 agent-relay 把『注册通知』派成一张卡 T-014，allowed_paths 只限 lib/ 和 routes/，验收命令 npm test」 | 生成任务卡（写死目标/范围/验收）并 push |
| 认领接手 | 「用 agent-relay 接手 T-014」 | sync → claim → 读 state/交接单/git log，先给 3 行结论再动手 |
| 跨会话续棒 | 「接着上次的 T-014 继续，按 relay 先 fetch 看交接单」 | sync 后接着已有分支做，不新建分支、不复制卡 |
| 收工交接 | 「T-014 做完了，跑验收门然后交接给下一棒」 | verify 全过 → handoff，交接单随代码同一次 push |
| 同会话换模型 | 换前：「给 T-014 打检查点，我要换模型」；新模型第一句：「新模型已就位，rebind T-014，先复述约束」 | checkpoint switch / rebind，落盘才算数 |
| 评审合并 | 「T-014 review 过了，用 relay 合并回 main」 | merge：rebase + `--no-ff` 合并 |
| 方向错了废卡 | 「T-014 这张卡不成立，打 tag 留档从 main 重开」 | 废卡流程：分支打 tag 不合并，重新派单 |

只要话里带任务号和动作词，Skill 会自己决定调哪个脚本；脚本参数细节见下方「最小用法」。**核心口令心法：`TASK_ID` + 动作（派单 / 接手 / 继续 / 交接 / 换模型 / 合并 / 废卡）。**

## 安装（用户级）

仓库根目录就是 Skill 根目录：

```bash
git clone git@github.com:aaroninpeace/multi-agents-relay.git ~/.workbuddy/skills/agent-relay
```

或直接从 Release / zip 解压到 `~/.workbuddy/skills/agent-relay/`。完成后在 WorkBuddy 中即可按 description 自动触发，或用 `/agent-relay` 调用。

依赖：`git`、`python3`、Bash 3.2+。无需第三方 Python 包、无需服务端或锁服务。

## 目录

```text
agent-relay/
├── SKILL.md                    # 触发条件 + 加载后立即执行的 3 步 + 工作流 + 资源索引
├── references/                 # 详细协议（按需加载）
│   ├── core-principles.md      # P1–P5、单工作区适配、两种交接
│   ├── workshop.md             # 仓库结构、七步循环、换棒、WIP 五格
│   ├── roles.md                # 七席位、能力矩阵、三种编队
│   ├── guardrails.md           # G1–G3、DoD、反模式、人工介入阈值
│   ├── templates.md            # 任务卡 / 交接单 / 检查点交接单 / Prompt
│   ├── state-schema.md         # state.json、状态机、log 事件、兼容
│   └── single-workspace.md     # 同会话换模型软交接完整规则
├── scripts/                    # 确定性脚本（直接执行，不必先读进上下文）
│   ├── relay-init.sh  relay-claim.sh  relay-sync.sh
│   ├── relay-verify.sh relay-handoff.sh relay-merge.sh
│   └── relay-checkpoint.sh     # 软交接：switch / rebind
├── assets/                     # 复制后填写的模板
│   ├── task-card.md  handoff.md  checkpoint-handoff.md
│   └── state.example.json
└── docs/agent-relay-playbook.html  # V1.3 人类阅读版手册
```

## 最小用法

```bash
# 目标仓库根目录
bash ~/.workbuddy/skills/agent-relay/scripts/relay-init.sh --task-id T-014 --model model-A
# 填好 .agent/tasks/T-014.md（frontmatter 的 allowed_paths / acceptance 必填）后 commit + push
bash ~/.workbuddy/skills/agent-relay/scripts/relay-claim.sh T-014
# 实现并跑绿，写好 .agent/handoffs/T-014.md 后
bash ~/.workbuddy/skills/agent-relay/scripts/relay-handoff.sh T-014
# 同会话换模型
bash ~/.workbuddy/skills/agent-relay/scripts/relay-checkpoint.sh T-014 switch model-B
bash ~/.workbuddy/skills/agent-relay/scripts/relay-checkpoint.sh T-014 rebind
# 评审通过后合并
bash ~/.workbuddy/skills/agent-relay/scripts/relay-merge.sh T-014
```

每条脚本用 `--help`（部分脚本用无参调用查看用法提示）查看参数。核心纪律：**commit + push 才算交接；DoD 不绿不许 handoff；仓库是唯一事实来源，聊天记录只作背景。**

## 版本

V1.3（2026-11-22）：新增 P5「换模型也是交接」、同会话换模型软交接检查点、state.session 字段与 relay-checkpoint.sh。
