#!/bin/bash
# Decides whether codex-ok.yml launches ci.yml on a PR (#246): the comment is Codex's clean-review receipt and the
# reviewed commit is the PR's current head. Prints the PR branch and exits 0 to launch, exits 1 with the reason
# otherwise, exits 2 on malformed input. Both inputs are untrusted JSON, only read by jq.
# Usage: branch=$(codex_ok.sh <issue_comment event.json> <GET /pulls/N response.json>)
set -euo pipefail
event=${1:?usage: codex_ok.sh <event.json> <pr.json>}
pr=${2:?usage: codex_ok.sh <event.json> <pr.json>}

no() { echo "no launch: $1" >&2; exit 1; }
# need <jq filter> <file> <reason>: jq -e exits 1 when the filter is false, other codes are real errors (bad JSON,
# wrong types) and must fail the job instead of looking like a normal "no launch".
need() {
  local rc=0
  jq -e "${@:4}" "$1" "$2" > /dev/null || rc=$?
  [ "$rc" -eq 0 ] && return
  [ "$rc" -eq 1 ] || { echo "jq failed ($rc) on $2" >&2; exit 2; }
  no "$3"
}

need '.action == "created"' "$event" "not a new comment"
need '.comment.user.login == "chatgpt-codex-connector[bot]" and .comment.user.type == "Bot"' "$event" \
  "author is not the Codex bot"
need '.issue.pull_request != null' "$event" "not a pull request"
# With findings the receipt sits in a pull_request_review body instead, never in an issue comment.
need '.comment.body | contains("<!-- codex-review-receipt:v1 -->") and contains("Didn'"'"'t find any major issues")' \
  "$event" "not a clean-review receipt"
reviewed=$(jq -r '.comment.body | capture("\\*\\*Reviewed commit:\\*\\* `(?<s>[0-9a-f]{7,40})`").s // empty' "$event")
[ -n "$reviewed" ] || no "no reviewed commit in the receipt"

need '.number == ($e[0].issue.number)' "$pr" "PR does not match the comment" --slurpfile e "$event"
need '.state == "open"' "$pr" "PR is not open"
need '.head.repo.full_name != null and .head.repo.full_name == .base.repo.full_name' "$pr" "PR comes from a fork"
need '.head.sha | startswith($r)' "$pr" "reviewed $reviewed is not the head" \
  --arg r "$reviewed"
jq -er '.head.ref | strings' "$pr"
