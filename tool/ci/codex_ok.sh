#!/bin/bash
# Decides whether codex-ok.yml restarts ci.yml's pull_request run (#246): the new comment approves the current head of
# an open, same-repo PR (approved.sh: Codex's clean receipt, or `ci-ok <sha>` from a user with write access read from
# the API). Prints "<head sha> <head branch>" and exits 0 to restart, exits 1 with the reason otherwise, exits 2 on
# malformed input. Both inputs are untrusted JSON, only read by jq. The gate in ci.yml re-checks on its own.
# Env: REPO, GH_TOKEN (for the permission of a `ci-ok` author).
# Usage: read -r sha branch < <(codex_ok.sh <issue_comment event.json> <GET /pulls/N response.json>)
set -euo pipefail
event=${1:?usage: codex_ok.sh <event.json> <pr.json>}
pr=${2:?usage: codex_ok.sh <event.json> <pr.json>}

no() { echo "no restart: $1" >&2; exit 1; }
# need <jq filter> <file> <reason>: jq -e exits 1 when the filter is false, other codes are real errors.
need() {
  local rc=0
  jq -e "${@:4}" "$1" "$2" > /dev/null || rc=$?
  [ "$rc" -eq 0 ] && return
  [ "$rc" -eq 1 ] || { echo "jq failed ($rc) on $2" >&2; exit 2; }
  no "$3"
}

need '.action == "created"' "$event" "not a new comment"
need '.issue.pull_request != null' "$event" "not a pull request"
need '.number == ($e[0].issue.number)' "$pr" "PR does not match the comment" --slurpfile e "$event"
need '.state == "open"' "$pr" "PR is not open"
need '.head.repo.full_name != null and .head.repo.full_name == .base.repo.full_name' "$pr" "PR comes from a fork"
head=$(jq -er '.head.sha | strings' "$pr") || { echo "no head sha in $pr" >&2; exit 2; }
branch=$(jq -er '.head.ref | strings' "$pr") || { echo "no head ref in $pr" >&2; exit 2; }

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
jq '[.comment]' "$event" > "$dir/comment.json"
rc=0
"$(dirname "$0")/approved.sh" "$dir/comment.json" "$head" >&2 || rc=$?
[ "$rc" -le 1 ] || exit "$rc"
[ "$rc" -eq 0 ] || no "the comment does not approve the head $head"
echo "$head $branch"
