#!/usr/bin/env bash
# 软交接检查点：
#   relay-checkpoint.sh TASK_ID switch NEW_MODEL [--old-model MODEL]
#   relay-checkpoint.sh TASK_ID rebind
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[[ $# -ge 2 ]] || relay_die "用法：relay-checkpoint.sh TASK_ID switch NEW_MODEL | relay-checkpoint.sh TASK_ID rebind"
TASK_ID="$1"; VERB="$2"; shift 2

relay_cd_root
relay_require_remote
relay_check_state
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "agent/${TASK_ID}" ]] || relay_die "当前分支 $BRANCH ≠ agent/${TASK_ID}"

if [[ "$VERB" == "switch" ]]; then
  NEW_MODEL="${1:-}"
  shift || true
  OLD_MODEL="$(relay_state_get session.model)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --old-model) OLD_MODEL="${2:-}"; shift 2 ;;
      *) relay_die "未知参数：$1" ;;
    esac
  done
  [[ -n "$NEW_MODEL" ]] || relay_die "switch 需要 NEW_MODEL"
  [[ "$NEW_MODEL" =~ ^[A-Za-z0-9._/-]+$ ]] || relay_die "模型标识只允许字母数字与 . _ / -"
  [[ -n "$OLD_MODEL" ]] || OLD_MODEL="unknown"

  # 1) 当前改动先落盘
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    relay_commit_push "wip(relay): checkpoint ${TASK_ID} before model switch"
  fi
  CHECKPOINT_COMMIT="$(git rev-parse HEAD)"
  SHORT="${CHECKPOINT_COMMIT:0:7}"
  CHECKPOINT_PATH=".agent/handoffs/${TASK_ID}-checkpoint-${SHORT}.md"

  # 2) 从模板生成检查点交接单骨架
  python3 - "$CHECKPOINT_PATH" "$TASK_ID" "$CHECKPOINT_COMMIT" "$OLD_MODEL" "$NEW_MODEL" "${RELAY_ASSETS_DIR}/checkpoint-handoff.md" <<'PY'
import sys
path, task, commit, old, new, template = sys.argv[1:]
with open(template, encoding="utf-8") as fh:
    text = fh.read()
for key, value in {
    "TASK_ID": task,
    "CHECKPOINT_COMMIT": commit,
    "FROM_MODEL": old,
    "TO_MODEL": new,
}.items():
    text = text.replace(key, value)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
PY

  # 3) 更新 state.session 与审计日志
  AT="$(relay_now)"
  relay_state_set "session.handoff_kind=model_switch" \
    "session.checkpoint_commit=${CHECKPOINT_COMMIT}" \
    "session.checkpoint_handoff=${CHECKPOINT_PATH}" \
    "session.pending_model=${NEW_MODEL}"
  python3 "$RELAY_LIB" state-append-history .agent/state.json "$OLD_MODEL" "$CHECKPOINT_COMMIT" "$AT"
  relay_log "$TASK_ID" model_switch "$CHECKPOINT_COMMIT" "${OLD_MODEL}→${NEW_MODEL}"

  git add -A
  git commit -m "chore(relay): model checkpoint ${TASK_ID} ${OLD_MODEL}->${NEW_MODEL}"
  git push

  printf '⟪RELAY-CHECKPOINT: %s @ %s @ %s → %s⟫\n' "$TASK_ID" "$CHECKPOINT_COMMIT" "$OLD_MODEL" "$NEW_MODEL"
  relay_info "检查点交接单：${CHECKPOINT_PATH}（必须补齐四行约束重述）"
  relay_info "新模型第一步：读 state.json → 检查点交接单 → git log -1，复述约束后才能动手"
  relay_info "绑定完成后运行：relay-checkpoint.sh $TASK_ID rebind"
  exit 0
fi

if [[ "$VERB" == "rebind" ]]; then
  PENDING="$(relay_state_get session.pending_model)"
  [[ -n "$PENDING" ]] || relay_die "session.pending_model 为空；先运行 switch"
  CHECKPOINT_COMMIT="$(relay_state_get session.checkpoint_commit)"
  CHECKPOINT_HANDOFF="$(relay_state_get session.checkpoint_handoff)"
  if [[ -n "$CHECKPOINT_HANDOFF" && ! -f "$CHECKPOINT_HANDOFF" ]]; then
    relay_die "检查点交接单缺失：$CHECKPOINT_HANDOFF"
  fi
  relay_state_set "session.model=${PENDING}" "session.pending_model=null"
  relay_log "$TASK_ID" model_rebind "$CHECKPOINT_COMMIT" "$PENDING"
  git add -A
  git commit -m "chore(relay): model rebind ${TASK_ID} -> ${PENDING}"
  git push
  relay_info "REBIND_OK $TASK_ID → $PENDING"
  exit 0
fi

relay_die "未知动作：$VERB（只支持 switch / rebind）"
