#!/usr/bin/env bash
# 只读同步与状态报告：relay-sync.sh [TASK_ID]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

relay_cd_root
relay_require_remote
git fetch --all --prune

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(detached)')"
HEAD_SHA="$(git rev-parse --short HEAD)"
relay_info "当前分支：$BRANCH @ $HEAD_SHA"

if UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  AHEAD="$(git rev-list --count "${UPSTREAM}..HEAD")"
  BEHIND="$(git rev-list --count "HEAD..${UPSTREAM}")"
  relay_info "上游：$UPSTREAM（ahead $AHEAD / behind $BEHIND）"
else
  relay_info "上游：未设置（尚未 push -u）"
fi

if [[ $# -ge 1 ]]; then
  TASK_ID="$1"
  if git show-ref --verify --quiet "refs/remotes/origin/agent/${TASK_ID}"; then
    relay_info "远程分支：agent/${TASK_ID} 已存在 → 续棒，不新建分支"
    REMOTE_SHA="$(git rev-parse --short "origin/agent/${TASK_ID}")"
    relay_info "远程 HEAD：$REMOTE_SHA"
  else
    relay_info "远程分支：agent/${TASK_ID} 不存在 → 可 relay-claim.sh ${TASK_ID}"
  fi
  if [[ -f .agent/state.json ]]; then
    relay_info "state: status=$(relay_state_get status) owner=$(relay_state_get owner) model=$(relay_state_get session.model)"
    relay_info "state: last_green_commit=$(relay_state_get last_green_commit) handoff_kind=$(relay_state_get session.handoff_kind)"
  fi
  if [[ -f ".agent/handoffs/${TASK_ID}.md" ]]; then
    relay_info "交接单存在：.agent/handoffs/${TASK_ID}.md"
  else
    relay_info "交接单缺失：.agent/handoffs/${TASK_ID}.md"
  fi
fi

relay_info "近期提交："
git log --oneline -3 || true
