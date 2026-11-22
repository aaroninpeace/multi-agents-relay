---
task_id: T-014
branch: agent/T-014
last_commit: a1b2c3d
status: handoff
done:
  - 已完成事项 1（到提交号）
done_placeholder: 删除这一行
remaining:
  - 未完成事项 1
next_action: 只写一个可执行的下一动作
pitfalls:
  - 踩过的坑 1（每条 ≤ 2 行）
schema_version: 1
---

# T-014 交接单

## 状态

已完成 / 部分完成（写明差哪一步）

## 做了什么

- 已完成事项 1（到提交号）

## 没做什么（重要）

- 未完成事项 1

## 怎么验证

```bash
git fetch && git switch agent/T-014
pnpm build && pnpm test
```

## 留给下一棒

1. 只写一个可执行的下一动作
2. 第二个动作（可选）

## 踩过的坑

- 踩过的坑 1（每条 ≤ 2 行）

> 全文 ≤ 400 字；详细材料放仓库内文件并用链接引用。`last_commit` 填最后一次代码绿色提交，与 state.last_green_commit 一致。
