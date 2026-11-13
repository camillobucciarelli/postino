#!/bin/bash
# Codex gate of ci.yml (#246): on a pull_request run the job fails within seconds, before any Flutter work, unless the
# PR head is approved: Codex's clean receipt on it, or `ci-ok <sha>` from a user with write access. Fails, never
# skips: a skipped required check counts as passed. Comments are read live, so a rerun sees approvals given later.
# Env: EVENT, REPO, PR, HEAD_SHA, GH_TOKEN (pull-requests: read).
set -euo pipefail
[ "$EVENT" = pull_request ] || exit 0
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

gh api --paginate "repos/$REPO/issues/$PR/comments" | jq -s 'add // []' > "$dir/comments.json"
rc=0
approvals=$("$(dirname "$0")/approval.sh" "$dir/comments.json" "$HEAD_SHA") || rc=$?
[ "$rc" -le 1 ] || exit "$rc"
while read -r kind login; do
  case $kind in
    codex) echo "Codex ok on $HEAD_SHA"; exit 0 ;;
    manual)
      permission=$(gh api "repos/$REPO/collaborators/$login/permission" --jq .permission)
      case $permission in admin | maintain | write) echo "ci-ok on $HEAD_SHA by $login"; exit 0 ;; esac ;;
  esac
done <<< "$approvals"
echo "::error::Waiting for Codex's ok on $HEAD_SHA (or a \`ci-ok <sha>\` comment from a collaborator with write access)"
exit 1
