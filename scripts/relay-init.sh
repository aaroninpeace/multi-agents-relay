#!/usr/bin/env bash
# 初始化仓库的 relay 协议骨架。用法：relay-init.sh [--task-id T-014] [--model model-A] [--push]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TASK_ID=""
MODEL="unknown"
DO_PUSH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --push) DO_PUSH=1; shift ;;
    -h|--help)
      sed -n '2,4p' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) relay_die "未知参数：$1" ;;
  esac
done

relay_cd_root
mkdir -p .agent/tasks .agent/handoffs

if [[ ! -f .agent/state.json ]]; then
  SESSION_ID="s-$(date +%Y%m%d)-01"
  python3 "$RELAY_LIB" state-init .agent/state.json "${TASK_ID:-TASK_ID}" "$MODEL" "$SESSION_ID"
fi
if [[ ! -f .agent/log.md ]]; then
  printf '# Relay Log\n\n' > .agent/log.md
fi
if [[ ! -f AGENTS.md ]]; then
  cat > AGENTS.md <<'EOF'
# AGENTS.md · 项目公约

## 技术栈

（填写语言、框架、包管理器）

## 验收命令

- build: （填写真实命令）
- test: （填写真实命令）
- lint: （填写真实命令）

## 目录约定

（填写源码目录、禁止改动目录）

## 禁止事项

- 不改 .env* 与任何密钥文件
- 不直推 main
- 交接单必须随代码一起 push
EOF
  relay_info "已生成 AGENTS.md 骨架，请补齐技术栈与三条验收命令"
fi

if [[ -n "$TASK_ID" ]]; then
  relay_info "任务卡模板：${RELAY_ASSETS_DIR}/task-card.md → .agent/tasks/${TASK_ID}.md"
fi
relay_info "骨架就绪：.agent/{tasks,handoffs,state.json,log.md} + AGENTS.md"
if [[ $DO_PUSH -eq 1 ]]; then
  relay_commit_push "chore(relay): init protocol"
else
  relay_info "下一步：补齐 AGENTS.md 与任务卡，然后 git add -A && git commit -m 'chore(relay): init protocol' && git push"
fi
