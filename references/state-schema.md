# state.json schema、状态机与审计日志

## state.json（schema_version 1）

路径：`.agent/state.json`。由 `relay-init.sh` 从 `assets/state.example.json` 生成；`relay-*.sh` 负责更新，Agent 不要手改字段名。

```json
{
  "schema_version": 1,
  "task_id": "T-014",
  "status": "in_progress",
  "owner": "实现席",
  "branch": "agent/T-014",
  "base_commit": "a1b2c3d",
  "last_green_commit": "e4f5g6h",
  "blockers": [],
  "updated_at": "2026-11-22T09:00:00+08:00",
  "session": {
    "id": "s-20261122-01",
    "model": "model-B",
    "handoff_kind": "model_switch",
    "checkpoint_commit": "e4f5g6h",
    "checkpoint_handoff": ".agent/handoffs/T-014-checkpoint-e4f5g6.md",
    "pending_model": null,
    "model_history": [
      { "model": "model-A", "until": "e4f5g6h", "at": "2026-11-22T09:00:00+08:00" }
    ]
  }
}
```

字段说明：

| 字段 | 含义 | 谁写 |
| --- | --- | --- |
| `status` | 当前状态枚举，见状态机 | claim / handoff / merge / blocked 脚本 |
| `owner` | **席位**（产品席 / 实现席 …），不是模型名 | claim / handoff |
| `branch` | `agent/<TASK_ID>` | claim |
| `base_commit` | 从 main 切出时的提交 | claim |
| `last_green_commit` | 最近一次通过 DoD 的代码提交 | handoff（= 交接单 last_commit） |
| `blockers` | 阻塞项数组；非空时通常配套 `status=blocked` | 人工 / 脚本 |
| `session.id` | 会话标识；同一会话内换模型保持不变 | init |
| `session.model` | 当前模型标识 | checkpoint rebind |
| `session.handoff_kind` | `session_end` 或 `model_switch` | claim / checkpoint switch |
| `session.checkpoint_commit` | 换模型那一刀落在哪个提交 | checkpoint switch |
| `session.checkpoint_handoff` | 检查点交接单路径 | checkpoint switch |
| `session.pending_model` | switch 后待绑定的新模型；rebind 后清空 | checkpoint switch / rebind |
| `session.model_history` | 同会话内模型切换轨迹（含截止提交与时间） | checkpoint switch |

## 状态机

```text
todo ──claim──▶ claimed ──start──▶ in_progress ──verify 全绿──▶ handoff ──review──▶ in_review ──merge──▶ merged
                    │                  │
                    │                  └─ verify_fail ≥3 ─▶ blocked ──@人裁决──▶ 恢复 / abandoned
                    └─ 需求作废 ──────────────────────────────▶ abandoned（打 tag 留档）

⟳ model_switch（同会话换模型）不改变主状态，只写检查点：
  commit + push → state.session 更新 → 检查点交接单 → 新模型读仓库三件套 → rebind
```

规则：

- 只有 `verify` 全绿才允许写入 `status=handoff`；`relay-handoff.sh` 内部强制调用 `relay-verify.sh`。
- `merged` 由 `relay-merge.sh` 在 no-ff 合并成功后写入。
- `abandoned` 的分支打 tag 留档，不合并；写一句话原因，避免下一棒重走。
- `model_switch` 是正交事件：不改变 `status`，只在 session 段留检查点。

## log.md 事件

只追加，不重写。事件枚举：

`claim` · `handoff` · `verify_fail` · `merge` · `rework` · `question` · `blocked` · `model_switch` · `model_rebind` · `model_rebind_mismatch`

固定字段：时间戳（ISO 8601 带时区）/ 席位 / task_id / 事件类型 / 提交号 / 模型标识（换模型相关事件必填）。示例：

```text
2026-11-22T09:00:00+08:00 | 实现席 | T-014 | claim | a1b2c3d | model-A
2026-11-22T10:20:00+08:00 | 实现席 | T-014 | verify_fail | e4f5g6h | model-A | lint: 3 errors
2026-11-22T10:35:00+08:00 | 实现席 | T-014 | model_switch | e4f5g6h | model-A→model-B
2026-11-22T10:40:00+08:00 | 实现席 | T-014 | model_rebind | e4f5g6h | model-B
```

复盘指标：接手方提问次数（`question` 计数）、返工次数（`rework` 计数）、verify 失败次数。一键聚合可用 `grep -c '<event>' .agent/log.md`。

## 版本兼容

- 读取 state 时缺 `session` 段 → 按 `session_end` 默认处理，不报错。
- 缺 `schema_version` → 按 1 处理，并在下一次写入时补齐。
- 新增字段一律向后兼容；破坏性变更（状态枚举改名、字段删除、分支约定变化）升主版本并提供迁移说明。
- 本 Skill 当前版本 V1.3（对应 HTML 手册 V1.3）。
