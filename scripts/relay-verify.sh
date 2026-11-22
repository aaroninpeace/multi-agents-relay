#!/usr/bin/env bash
# DoD 自动校验：relay-verify.sh T-014 [--skip-acceptance]
# 不通过则退出非 0，禁止 relay-handoff.sh 写入 handoff。
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[[ $# -ge 1 ]] || relay_die "用法：relay-verify.sh TASK_ID [--skip-acceptance]"
TASK_ID="$1"; shift
SKIP_ACCEPTANCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-acceptance) SKIP_ACCEPTANCE=1; shift ;;
    *) relay_die "未知参数：$1" ;;
  esac
done

relay_cd_root
relay_require_remote
relay_check_state
git fetch --all --prune

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "agent/${TASK_ID}" ]] || relay_die "当前分支 $BRANCH ≠ agent/${TASK_ID}"
relay_require_clean
git show-ref --verify --quiet refs/remotes/origin/main || relay_die "缺少 origin/main"

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
  || relay_die "分支未设置上游；先 git push -u origin agent/${TASK_ID}"
LOCAL_SHA="$(git rev-parse HEAD)"
UP_SHA="$(git rev-parse "$UPSTREAM")"
[[ "$LOCAL_SHA" == "$UP_SHA" ]] || relay_die "本地 HEAD 与 $UPSTREAM 不一致；先 push"

TASK_CARD=".agent/tasks/${TASK_ID}.md"
HANDOFF=".agent/handoffs/${TASK_ID}.md"
[[ -f "$TASK_CARD" ]] || relay_die "缺少任务卡 $TASK_CARD"
ALLOWED_JSON="$(relay_frontmatter "$TASK_CARD" allowed_paths)"
[[ -n "$ALLOWED_JSON" && "$ALLOWED_JSON" != '[]' ]] || relay_die "任务卡缺 allowed_paths，无法校验改动范围"

ALLOWED=()
while IFS= read -r line; do ALLOWED+=("$line"); done < <(python3 -c 'import json,sys;[print(x) for x in json.loads(sys.argv[1])]' "$ALLOWED_JSON")
# 协议文件（.agent/**）随分支提交但不计入业务改动范围
CHANGED=()
while IFS= read -r line; do CHANGED+=("$line"); done < <(git diff --name-only origin/main...HEAD | grep -v '^\.agent/' || true)
[[ ${#CHANGED[@]} -gt 0 ]] || relay_die "相对 origin/main 没有代码改动"

for file in "${CHANGED[@]}"; do
  ok=0
  for prefix in "${ALLOWED[@]}"; do
    prefix="${prefix%/}"
    if [[ "$file" == "$prefix" || "$file" == "$prefix/"* ]]; then ok=1; break; fi
  done
  [[ $ok -eq 1 ]] || relay_die "改动越界：$file 不在任务卡 allowed_paths 内"
done

[[ -f "$HANDOFF" ]] || relay_die "缺少交接单 $HANDOFF"
git cat-file -e "HEAD:${HANDOFF}" 2>/dev/null || relay_die "交接单存在于工作区但未提交到 HEAD"
LAST_COMMIT="$(relay_frontmatter "$HANDOFF" last_commit)"
GREEN="$(relay_state_get last_green_commit)"
[[ -n "$LAST_COMMIT" ]] || relay_die "交接单 last_commit 为空"
# 首次交接时 state.last_green_commit 允许为空；已有值必须与交接单一致
if [[ -n "$GREEN" ]]; then
  [[ "$LAST_COMMIT" == "$GREEN" ]] || relay_die "交接单 last_commit=$LAST_COMMIT ≠ state.last_green_commit=$GREEN"
fi
git merge-base --is-ancestor "$LAST_COMMIT" HEAD || relay_die "交接单绿色提交 $LAST_COMMIT 不在当前分支历史中"

KIND="$(relay_state_get session.handoff_kind)"
if [[ "$KIND" == "model_switch" ]]; then
  CHECKPOINT_COMMIT="$(relay_state_get session.checkpoint_commit)"
  CHECKPOINT_HANDOFF="$(relay_state_get session.checkpoint_handoff)"
  [[ -n "$CHECKPOINT_COMMIT" && -n "$CHECKPOINT_HANDOFF" ]] \
    || relay_die "model_switch 缺 session.checkpoint_commit / checkpoint_handoff"
  git cat-file -e "${CHECKPOINT_COMMIT}^{commit}" 2>/dev/null || relay_die "检查点提交不存在：$CHECKPOINT_COMMIT"
  git merge-base --is-ancestor "$CHECKPOINT_COMMIT" HEAD || relay_die "检查点提交不在当前分支"
  git cat-file -e "HEAD:${CHECKPOINT_HANDOFF}" 2>/dev/null || relay_die "检查点交接单未推送：$CHECKPOINT_HANDOFF"
  CP_COMMIT="$(relay_frontmatter "$CHECKPOINT_HANDOFF" checkpoint_commit)"
  [[ "$CP_COMMIT" == "$CHECKPOINT_COMMIT" ]] \
    || relay_die "检查点交接单 commit=$CP_COMMIT ≠ state=$CHECKPOINT_COMMIT"
fi

if [[ $SKIP_ACCEPTANCE -eq 1 ]]; then
  relay_info "警告：--skip-acceptance，验收命令未执行，DoD 1-3 未验证"
else
  ACCEPT=()
  while IFS= read -r line; do ACCEPT+=("$line"); done < <(python3 -c 'import json,sys;[print(x) for x in json.loads(sys.argv[1])]' "$(relay_frontmatter "$TASK_CARD" acceptance)")
  [[ ${#ACCEPT[@]} -gt 0 ]] || relay_die "任务卡缺 acceptance 验收命令"
  for cmd in "${ACCEPT[@]}"; do
    relay_info "执行验收命令：$cmd"
    if ! bash -lc "$cmd"; then
      relay_log "$TASK_ID" verify_fail "$GREEN" "$(relay_state_get session.model)" "accept failed: $cmd"
      relay_die "验收命令失败：$cmd"
    fi
  done
fi

if git diff origin/main...HEAD -- . ':(exclude).agent/**' \
    | grep -nE '^\+.*(API_KEY|SECRET|PASSWORD|PRIVATE KEY|console\.log|debugger)' >/dev/null; then
  relay_die "新增行中疑似密钥或调试残留；请清理后再验证"
fi

UNTRACKED="$(git status --porcelain --untracked-files=normal | grep '^??' || true)"
if [[ -n "$UNTRACKED" ]]; then
  relay_info "提示：存在未跟踪文件（未参与校验）："
  printf '%s\n' "$UNTRACKED"
fi

if [[ $SKIP_ACCEPTANCE -eq 1 ]]; then ACCEPT_LABEL="跳过"; else ACCEPT_LABEL="通过"; fi
relay_info "VERIFY_OK ${TASK_ID} @ ${LOCAL_SHA:0:7}（范围 ${#CHANGED[@]} 文件，验收 ${ACCEPT_LABEL}）"
relay_info "下一步：relay-handoff.sh $TASK_ID"
