#!/bin/bash
# Self-check of approval.sh, run by ci.yml: only Codex's clean receipt or `ci-ok <sha>` on the head approve it.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

head=4cdb814d898b3b3c22f464f39d8cae61a8a7b5cd
receipt=$'<!-- codex-review-receipt:v1 -->\n\nCodex Review: Didn\'t find any major issues. Swish!\n\n**Reviewed commit:** `4cdb814d89`\n'
# comments <jq filter applied to [Codex receipt, unrelated user comment]>
comments() {
  jq -n --arg body "$receipt" '[{body: $body, user: {login: "chatgpt-codex-connector[bot]", type: "Bot"}},
    {body: "@codex review", user: {login: "dev", type: "User"}}]' | jq "$1" > "$dir/c.json"
}
expect() {
  comments "$1"
  local out rc=0
  out=$(tool/ci/approval.sh "$dir/c.json" "$head" 2> /dev/null) || rc=$?
  [ "$rc:$out" = "$2" ] || { echo "approval.sh on $1: got '$rc:$out', want '$2'"; exit 1; }
}

expect . '0:codex'
expect '.[0].body |= sub("4cdb814d89"; "4cdb814d898b3b3c22f464f39d8cae61a8a7b5cd")' '0:codex'
expect '.[0].user.login = "someone"' '1:'
expect '.[0].user.type = "User"' '1:'
expect '.[0].user.login = "chatgpt-codex-connector"' '1:'
expect '.[0].body |= sub("Didn.t find any major issues"; "Found 2 issues")' '1:'
expect '.[0].body |= sub("<!-- codex-review-receipt:v1 -->"; "")' '1:'
expect '.[0].body |= sub("4cdb814d89"; "b805158c46")' '1:'
expect '.[0].body |= sub("\\*\\*Reviewed commit:\\*\\* `4cdb814d89`"; "")' '1:'
expect '.[1].body = "ci-ok 4cdb814"' $'0:codex\nmanual dev'
expect 'del(.[0]) | .[0].body = "ci-ok 4cdb814d89\n"' '0:manual dev'
expect 'del(.[0]) | .[0].body = "ci-ok b805158"' '1:'
expect 'del(.[0]) | .[0].body = "ci-ok 4cdb81"' '1:'
expect 'del(.[0]) | .[0].body = "please ci-ok 4cdb814"' '1:'
expect 'del(.[0]) | .[0].body = "ci-ok 4cdb814" | .[0].user.type = "Bot"' '1:'
expect '[]' '1:'
expect '.[0].body = null' '2:'
printf '[{"body": "ci-ok' > "$dir/c.json"
rc=0
tool/ci/approval.sh "$dir/c.json" "$head" > /dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || { echo "malformed JSON: rc=$rc, want 2"; exit 1; }
echo "approval.sh ok"
