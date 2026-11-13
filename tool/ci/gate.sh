#!/bin/bash
# Codex gate of ci.yml (#246): on a pull_request run the job fails within seconds, before any Flutter work, unless the
# PR head is approved (approved.sh). Fails, never skips: a skipped required check counts as passed. Comments are read
# live, so a rerun sees approvals given later.
# Env: EVENT, REPO, PR, HEAD_SHA, GH_TOKEN (pull-requests: read).
set -euo pipefail
[ "$EVENT" = pull_request ] || exit 0
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

gh api --paginate "repos/$REPO/issues/$PR/comments" | jq -s 'add // []' > "$dir/comments.json"
rc=0
"$(dirname "$0")/approved.sh" "$dir/comments.json" "$HEAD_SHA" || rc=$?
[ "$rc" -ne 1 ] || echo "::error::Waiting for Codex's ok on $HEAD_SHA (or \`ci-ok <sha>\` from a collaborator with write access)"
exit "$rc"
