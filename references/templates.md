# 模板集（六份 + 软交接检查点）

> 模板的价值不在写得多漂亮，而在每一棒都填同样几个格子。空格固定，缺什么一眼就能看出来。带 YAML frontmatter 的版本供脚本解析；纯文本示例供人阅读。复制 `assets/` 下的文件后按实际内容填写。

## 1 · 任务卡 `.agent/tasks/T-014.md`

````markdown
---
id: T-014
title: 价格页新增区间筛选
branch: agent/T-014
allowed_paths:
  - src/routes/pricing.tsx
  - src/components/PriceFilter.tsx
acceptance:
  - pnpm build
  - pnpm test
schema_version: 1
---

# T-014 价格页新增区间筛选

## 分支
agent/T-014（认领后由实现席从最新 main 切出）

## 目标
价格页新增 ¥0-100 / ¥100-500 / ¥500+ 三档筛选，选中后列表实时收敛。

## 验收标准（缺一不可）
- [ ] 切换档位后列表只显示对应区间商品
- [ ] 清空筛选恢复全量
- [ ] pnpm build 通过，页面无 console 报错

## 允许改动
- src/routes/pricing.tsx
- src/components/PriceFilter.tsx（可新建）

## 不要碰
src/lib/api.ts、数据库 schema、任何 .env*

## 已知约束
筛选在前端做，不改接口；宽度 <= 640px 时按钮换行。
````

规则：一个可验收目标；验收命令必须是能在本地执行的真命令；allowed_paths 用仓库相对路径前缀，脚本按前缀比对 diff。

## 2 · 交接单 `.agent/handoffs/T-014.md`

````markdown
---
task_id: T-014
branch: agent/T-014
last_commit: a1b2c3d
status: handoff
done:
  - 新增 PriceFilter 组件：三档区间 + 清空按钮
  - 改动 src/routes/pricing.tsx，接入过滤逻辑
remaining:
  - 补 <= 640px 的换行样式
  - 给过滤函数加 3 个单测
next_action: 补 <= 640px 的换行样式
pitfalls:
  - 区间一开始写成闭区间，100 同时命中第一档；已改为 (a, b]，别再改回去。
schema_version: 1
---

# T-014 交接单

## 状态
已完成 / 部分完成（写明差哪一步）

## 做了什么
- 新增 PriceFilter 组件：三档区间 + 清空按钮
- 改动 src/routes/pricing.tsx，接入过滤逻辑

## 没做什么（重要）
- 未做移动端换行：设计稿缺失，没敢定
- 未补单测

## 怎么验证
git fetch && git switch agent/T-014
pnpm build && pnpm dev
打开 /pricing，依次点 100-500、清空

## 留给下一棒
1. 补 <= 640px 的换行样式
2. 给过滤函数加 3 个单测：空档位、边界值 100、超出范围

## 踩过的坑
区间一开始写成闭区间，100 同时命中第一档；已改为 (a, b]，别再改回去。
````

`last_commit` 填最后一次**代码**绿色提交（不含随后的 chore 提交）；与 state.last_green_commit 保持一致。全文 ≤ 400 字。

## 3 · 检查点交接单（同会话换模型）`.agent/handoffs/T-014-checkpoint-<sha>.md`

````markdown
---
task_id: T-014
handoff_kind: model_switch
checkpoint_commit: e4f5g6h
from_model: model-A
to_model: model-B
status: handoff
schema_version: 1
---

# T-014 换模型检查点

## 已完成
（列到提交号）

## 剩余
（只列未完成项）

## 下一动作
（只写一个可执行动作）

## 约束重述（新模型必须先复述这四行）
- allowed_paths: src/routes/pricing.tsx, src/components/PriceFilter.tsx
- 验收命令: pnpm build / pnpm test
- DoD: 六条全绿 + 改动未越界 + 交接单已 push
- 当前 status: in_progress

## 踩过的坑
（每条 ≤ 2 行）
````

由 `relay-checkpoint.sh TASK_ID switch NEW_MODEL` 从 `assets/checkpoint-handoff.md` 生成骨架；Agent 必须补齐「已完成 / 剩余 / 下一动作 / 约束重述」再 commit + push。

## 4 · 提交信息

```text
feat(pricing): 新增价格区间筛选 [T-014]

- 三档区间 + 清空，前端过滤未改接口
- 移动端换行与单测待补

Refs: .agent/tasks/T-014.md
Branch: agent/T-014
Next: 补 <= 640px 换行与 3 个单测
```

WIP 用 `wip(T-014): 做完 X，卡在 Y`；交接元数据用 `chore(relay): handoff T-014 @ <sha>`；合并用 `merge(relay): T-014`。

## 5 · 派单 Prompt（粘给产品席）

```text
你是本项目的【产品席】。你只读仓库、只写 .agent/ 下的文档，不改 src/。

步骤：
1. 先 git fetch --all，读 AGENTS.md 与远端已有任务卡
2. 把我的需求拆成不超过 3 张任务卡，写入 .agent/tasks/
3. 每张卡必须含：一个可验收目标、验收命令、允许改动目录、分支名、明确不做的事
4. commit 并 push 到 main（或派单分支），让所有克隆都能 fetch 到
5. 完成后只回卡片路径和一句话摘要，不要解释你的思路

需求：<在这里贴需求>
```

## 6 · 接手 Prompt（粘给实现席）

```text
你是【实现席】，接手任务卡 .agent/tasks/T-014.md。

开工前必须：
1. git fetch --all --prune，确认 origin 上有没有同名 agent/T-014 分支（有则续棒，不新建）
2. 读 AGENTS.md、.agent/state.json、最近的 .agent/handoffs/*.md
3. 只读勘察，先给我 3 行结论：现状 / 要改的文件 / 风险
4. 我确认后再切分支：git switch -c agent/T-014 && git push -u origin agent/T-014

改动不得超出任务卡的「允许改动」范围。
完成后跑完验收命令，再把代码和 handoffs/T-014.md 一起 commit + push。
```

## 7 · 同步命令（开工 / 收工）

```bash
# 开工
git fetch --all --prune
git switch main && git pull --ff-only
git switch -c agent/T-014
git push -u origin agent/T-014

# 收工
git add -A
git commit -m "feat(x): 摘要 [T-014]"
git push
git fetch
git rebase origin/main
git switch main && git merge --no-ff agent/T-014
```

> 复制只是起点。真正的门槛是：下一棒拿到这张纸，能不能一句都不问就开工。做不到时，缺的那条就是下一次要补进模板的字段。
