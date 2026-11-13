#!/bin/bash
# Decides whether codex-ok.yml launches ci.yml on a PR (#246): the comment is Codex's clean-review receipt and the
# reviewed commit is the PR's current head. Prints the PR branch and exits 0 to launch, exits 1 with the reason
# otherwise. Both inputs are untrusted JSON, only read by jq.
# Usage: branch=$(codex_ok.sh <issue_comment event.json> <GET /pulls/N response.json>)
set -euo pipefail
event=${1:?usage: codex_ok.sh <event.json> <pr.json>}
pr=${2:?usage: codex_ok.sh <event.json> <pr.json>}

no() { echo "no launch: $1" >&2; exit 1; }

jq -e '.action == "created"' "$event" > /dev/null || no "not a new comment"
jq -e '.comment.user.login == "chatgpt-codex-connector[bot]" and .comment.user.type == "Bot"' "$event" > /dev/null \
  || no "author is not the Codex bot"
jq -e '.issue.pull_request != null' "$event" > /dev/null || no "not a pull request"
# With findings the receipt sits in a pull_request_review body instead, never in an issue comment.
jq -e '.comment.body | contains("<!-- codex-review-receipt:v1 -->") and contains("Didn'"'"'t find any major issues")' \
  "$event" > /dev/null || no "not a clean-review receipt"
reviewed=$(jq -r '.comment.body | capture("\\*\\*Reviewed commit:\\*\\* `(?<s>[0-9a-f]{7,40})`").s // empty' "$event")
[ -n "$reviewed" ] || no "no reviewed commit in the receipt"

jq -e '.number == ($e[0].issue.number)' --slurpfile e "$event" "$pr" > /dev/null || no "PR does not match the comment"
jq -e '.state == "open"' "$pr" > /dev/null || no "PR is not open"
jq -e '.head.repo.full_name != null and .head.repo.full_name == .base.repo.full_name' "$pr" > /dev/null \
  || no "PR comes from a fork"
jq -e --arg r "$reviewed" '.head.sha | startswith($r)' "$pr" > /dev/null || no "reviewed $reviewed is not the head"
jq -r '.head.ref' "$pr"
