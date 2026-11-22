#!/usr/bin/env bash
# 写 handoff 并推送：relay-handoff.sh T-014 [--role 实现席]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[[ $# -ge 1 ]] || relay_die "用法：relay-handoff.sh TASK_ID [--role ROLE]"
TASK_ID="$1"; shift
RELAY_ROLE="实现席"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) RELAY_ROLE="${2:-}"; shift 2 ;;
    *) relay_die "未知参数：$1" ;;
  esac
done

relay_cd_root
relay_require_remote
relay_check_state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/relay-verify.sh" "$TASK_ID" || relay_die "DoD 校验未通过，禁止写 handoff"

GREEN="$(relay_frontmatter ".agent/handoffs/${TASK_ID}.md" last_commit)"
MODEL="$(relay_state_get session.model)"
relay_state_set "status=handoff" "owner=${RELAY_ROLE}" "last_green_commit=${GREEN}"
relay_log "$TASK_ID" handoff "$GREEN" "$MODEL"
git add -A
git commit -m "chore(relay): handoff ${TASK_ID} @ ${GREEN:0:7}"
git push

relay_info "HANDOFF_OK $TASK_ID @ ${GREEN:0:7}"
relay_info "下一步：下一棒运行 relay-sync.sh ${TASK_ID}，先读 state → handoff → git log -3 再动手"
