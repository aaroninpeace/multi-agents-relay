#!/usr/bin/env bash
# rebase + no-ff 合并：relay-merge.sh T-014
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[[ $# -ge 1 ]] || relay_die "用法：relay-merge.sh TASK_ID"
TASK_ID="$1"
relay_cd_root
relay_require_remote
relay_check_state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/relay-verify.sh" "$TASK_ID" || relay_die "DoD 校验未通过，禁止合并"

git fetch --all --prune
git switch "agent/${TASK_ID}"
if ! git rebase origin/main; then
  relay_die "rebase 冲突：在 agent/${TASK_ID} 上解决后重跑；不要在 main 上解冲突"
fi
git switch main
git pull --ff-only
MERGE_SHA_BEFORE="$(git rev-parse HEAD)"
git merge --no-ff "agent/${TASK_ID}" -m "merge(relay): ${TASK_ID}"
MERGE_SHA="$(git rev-parse HEAD)"
[[ "$MERGE_SHA" != "$MERGE_SHA_BEFORE" ]] || relay_die "合并未产生新提交（可能已合并）"

relay_state_set "status=merged" "branch=agent/${TASK_ID}" "last_green_commit=${MERGE_SHA}"
relay_log "$TASK_ID" merge "$MERGE_SHA" "$(relay_state_get session.model)"
git add -A
git commit -m "chore(relay): close ${TASK_ID}"
git push origin main

relay_info "MERGE_OK $TASK_ID @ ${MERGE_SHA:0:7}"
relay_info "分支 agent/${TASK_ID} 保留供追溯；如需清理由维护者决定"
