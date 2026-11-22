---
task_id: TASK_ID
handoff_kind: model_switch
checkpoint_commit: CHECKPOINT_COMMIT
from_model: FROM_MODEL
to_model: TO_MODEL
status: handoff
schema_version: 1
---

# TASK_ID 换模型检查点

## 已完成

- 列到提交号

## 剩余

- 只列未完成项

## 下一动作

只写一个可执行动作。

## 约束重述（新模型必须先复述这四行）

- allowed_paths: 从任务卡 frontmatter 抄写
- 验收命令: 从 AGENTS.md / 任务卡抄写
- DoD: 六条全绿 + 改动未越界 + 交接单已 push
- 当前 status: 从 state.json 抄写

## 踩过的坑

- 每条 ≤ 2 行

> 由 `relay-checkpoint.sh TASK_ID switch NEW_MODEL` 生成骨架后必须补齐内容再 push。分界线标记只是给人看的定位锚，权威在仓库。
