#!/bin/bash
# Decides whether PR comments approve a head commit (#246): Codex's clean receipt, or `ci-ok <sha>` from a user whose
# repository permission, read from the API, is write, maintain or admin. Prints every approval found (and every
# rejected `ci-ok`) for the log. Exits 0 when approved, 1 when not, 2 on malformed input or a failing API call.
# Env: REPO (owner/name), GH_TOKEN. Usage: approved.sh <comments.json: array of issue comments> <full head sha>
set -euo pipefail
comments=${1:?usage: approved.sh <comments.json> <head sha>}
head=${2:?usage: approved.sh <comments.json> <head sha>}

rc=0
found=$("$(dirname "$0")/approval.sh" "$comments" "$head") || rc=$?
[ "$rc" -le 1 ] || exit "$rc"
ok=1
while read -r kind login; do
  case $kind in
    codex) echo "Codex ok on $head"; ok=0 ;;
    manual)
      [[ $login =~ ^[A-Za-z0-9-]+$ ]] || { echo "not a user login: $login" >&2; exit 2; }
      permission=$(gh api "repos/$REPO/collaborators/$login/permission" --jq .permission) || exit 2
      case $permission in
        admin | maintain | write) echo "ci-ok on $head by $login ($permission)"; ok=0 ;;
        *) echo "ci-ok by $login ignored: permission $permission" ;;
      esac ;;
  esac
done <<< "$found"
exit "$ok"
