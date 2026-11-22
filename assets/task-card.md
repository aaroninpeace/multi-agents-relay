---
id: T-014
title: 在这里写一句话标题
branch: agent/T-014
allowed_paths:
  - src/path/to/file.ts
acceptance:
  - pnpm build
  - pnpm test
schema_version: 1
---

# T-014 在这里写一句话标题

## 分支

agent/T-014（认领后由实现席从最新 main 切出）

## 目标

写成一个可验收的目标，不写「优化体验」「完善功能」。

## 验收标准（缺一不可）

- [ ] 可观测的行为变化 1
- [ ] 可观测的行为变化 2
- [ ] 验收命令全部退出码为 0

## 允许改动

- src/path/to/file.ts

## 不要碰

明确列出禁止改动的文件、目录、配置与原因。

## 已知约束

接口限制、宽度限制、兼容性要求等。

## 验收命令

与 frontmatter 的 `acceptance` 保持一致；`relay-verify.sh` 会逐条执行这里的命令。
