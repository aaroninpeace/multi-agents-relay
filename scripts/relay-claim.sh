#!/usr/bin/env bash
# 认领任务卡：relay-claim.sh T-014 [--role 实现席] [--model model-A]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[[ $# -ge 1 ]] || relay_die "用法：relay-claim.sh TASK_ID [--role ROLE] [--model MODEL]"
TASK_ID="$1"; shift
RELAY_ROLE="实现席"
MODEL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) RELAY_ROLE="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    *) relay_die "未知参数：$1" ;;
  esac
done

relay_cd_root
relay_require_remote
relay_check_state
relay_require_clean
[[ -f ".agent/tasks/${TASK_ID}.md" ]] || relay_die "任务卡不存在：.agent/tasks/${TASK_ID}.md"

git fetch --all --prune
if git ls-remote --exit-code --heads origin "refs/heads/agent/${TASK_ID}" >/dev/null 2>&1; then
  relay_die "远程已存在 agent/${TASK_ID}：应续棒（switch + pull），不要新建分支抢卡"
fi

git switch main
git pull --ff-only
git switch -c "agent/${TASK_ID}"
git push -u origin "agent/${TASK_ID}"
BASE_COMMIT="$(git rev-parse HEAD)"

relay_state_set "task_id=${TASK_ID}" "status=claimed" "owner=${RELAY_ROLE}" \
  "branch=agent/${TASK_ID}" "base_commit=${BASE_COMMIT}" "last_green_commit=" \
  "session.handoff_kind=session_end" "blockers=[]"
if [[ -n "$MODEL" ]]; then
  relay_state_set "session.model=${MODEL}"
fi
relay_log "$TASK_ID" claim "$BASE_COMMIT" "$(relay_state_get session.model)"
relay_commit_push "chore(relay): claim ${TASK_ID}"

relay_info "已认领 agent/${TASK_ID} @ ${BASE_COMMIT:0:7}"
relay_info "下一步：只读勘察（state → handoff → git log -3），给用户 3 行结论后再动手"
