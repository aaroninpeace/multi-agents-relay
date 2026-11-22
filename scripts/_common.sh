#!/usr/bin/env bash
# Shared helpers for agent-relay scripts. Source from script directory.
set -euo pipefail

RELAY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELAY_ASSETS_DIR="$(cd "${RELAY_SCRIPT_DIR}/../assets" && pwd)"
RELAY_LIB="${RELAY_SCRIPT_DIR}/relay_lib.py"

relay_die() { printf '[relay] ERROR: %s\n' "$*" >&2; exit 1; }
relay_info() { printf '[relay] %s\n' "$*"; }

relay_cd_root() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || relay_die "当前目录不在 git 仓库内"
  cd "$root"
}

relay_now() { python3 "$RELAY_LIB" now; }

relay_state_get() { python3 "$RELAY_LIB" state-get .agent/state.json "$1"; }

relay_state_set() { python3 "$RELAY_LIB" state-set .agent/state.json "$@"; }

relay_frontmatter() { python3 "$RELAY_LIB" frontmatter "$1" "$2"; }

relay_require_remote() {
  git remote get-url origin >/dev/null 2>&1 || relay_die "缺少 origin 远端；先配置 Git 远端再运行"
}

relay_require_clean() {
  local dirty
  dirty="$(git status --porcelain --untracked-files=no)"
  [[ -z "$dirty" ]] || relay_die "工作区有未提交的跟踪文件改动；先 commit 再交接（stash 不算交接）"
}

relay_log() {
  # relay_log TASK_ID EVENT COMMIT MODEL [NOTE]
  local task="$1" event="$2" commit="${3:-}" model="${4:-}" note="${5:-}"
  mkdir -p .agent
  if [[ -n "$note" ]]; then
    printf '%s | %s | %s | %s | %s | %s | %s\n' \
      "$(relay_now)" "${RELAY_ROLE:-实现席}" "$task" "$event" "$commit" "$model" "$note" >> .agent/log.md
  else
    printf '%s | %s | %s | %s | %s | %s\n' \
      "$(relay_now)" "${RELAY_ROLE:-实现席}" "$task" "$event" "$commit" "$model" >> .agent/log.md
  fi
}

relay_commit_push() {
  # relay_commit_push "message"
  git add -A
  if git diff --cached --quiet; then
    relay_info "无改动需要提交：$1"
    return 0
  fi
  git commit -m "$1"
  git push
}

relay_check_state() {
  [[ -f .agent/state.json ]] || relay_die "缺少 .agent/state.json；先运行 relay-init.sh"
}
