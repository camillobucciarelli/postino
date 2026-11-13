#!/bin/bash
# Finds the approvals of a PR head commit among PR comments (#246), one per line:
#   codex          Codex's clean-review receipt whose reviewed commit is a prefix of the head
#   manual <login> a user's comment `ci-ok <sha>` with <sha> a prefix of the head; the caller must still check that
#                  <login> has write access
# Exits 0 with at least one approval, 1 with none, 2 on malformed input. Comments are untrusted JSON, only read by jq.
# Usage: approval.sh <comments.json: array of issue comments> <full head sha>
set -euo pipefail
comments=${1:?usage: approval.sh <comments.json> <head sha>}
head=${2:?usage: approval.sh <comments.json> <head sha>}
[[ $head =~ ^[0-9a-f]{40}$ ]] || { echo "not a full sha: $head" >&2; exit 2; }

rc=0
out=$(jq -r --arg h "$head" '
  .[]
  | if .user.login == "chatgpt-codex-connector[bot]" and .user.type == "Bot"
       and (.body | contains("<!-- codex-review-receipt:v1 -->") and contains("Didn'"'"'t find any major issues"))
    then (.body | capture("\\*\\*Reviewed commit:\\*\\* `(?<s>[0-9a-f]{7,40})`").s // "") as $s
      | select($s != "" and ($h | startswith($s))) | "codex"
    elif .user.type == "User" and (.body | test("^ci-ok [0-9a-f]{7,40}\\s*$"))
    then (.body | capture("^ci-ok (?<s>[0-9a-f]{7,40})").s) as $s
      | select($h | startswith($s)) | "manual \(.user.login)"
    else empty end' "$comments") || rc=$?
[ "$rc" -eq 0 ] || { echo "jq failed ($rc) on $comments" >&2; exit 2; }
[ -n "$out" ] || exit 1
echo "$out"
