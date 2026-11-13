#!/bin/bash
# Self-check of codex_ok.sh, run by ci.yml: only an approval of the open, same-repo PR head restarts CI.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

head=4cdb814d898b3b3c22f464f39d8cae61a8a7b5cd
receipt=$'<!-- codex-review-receipt:v1 -->\n\nCodex Review: Didn\'t find any major issues. Swish!\n\n**Reviewed commit:** `4cdb814d89`\n'
# event <jq filter applied to a good event>, pr <jq filter applied to a good PR>
event() {
  jq -n --arg body "$receipt" '{action: "created", issue: {number: 7, pull_request: {url: "x"}},
    comment: {body: $body, user: {login: "chatgpt-codex-connector[bot]", type: "Bot"}}}' | jq "$1" > "$dir/event.json"
}
pr() {
  jq -n --arg sha "$head" '{number: 7, state: "open", head: {sha: $sha, ref: "feat/x", repo: {full_name: "o/r"}},
    base: {repo: {full_name: "o/r"}}}' | jq "$1" > "$dir/pr.json"
}
launches() {
  event "$1"; pr "$2"
  [ "$(tool/ci/codex_ok.sh "$dir/event.json" "$dir/pr.json" 2> /dev/null)" = "$head" ] \
    || { echo "should restart: $1 | $2"; exit 1; }
}
skips() {
  event "$1"; pr "$2"
  if tool/ci/codex_ok.sh "$dir/event.json" "$dir/pr.json" > /dev/null 2>&1; then echo "should skip: $1 | $2"; exit 1; fi
}

# A broken input is an error (exit 2), never a silent "no launch" (exit 1).
errors() {
  event .; pr "$1"
  if [ -n "${2:-}" ]; then printf '%s' "$2" > "$dir/pr.json"; fi
  local rc=0
  tool/ci/codex_ok.sh "$dir/event.json" "$dir/pr.json" > /dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] || { echo "should error (rc=$rc): $1 ${2:-}"; exit 1; }
}

launches . .
launches '.comment.body |= sub("4cdb814d89"; "4cdb814d898b3b3c22f464f39d8cae61a8a7b5cd")' .
launches '.comment = {body: "ci-ok 4cdb814", user: {login: "dev", type: "User"}}' .
skips '.comment = {body: "ci-ok b805158", user: {login: "dev", type: "User"}}' .
skips '.comment.user.login = "someone"' .
skips '.comment.user.type = "User"' .
skips '.action = "edited"' .
skips 'del(.issue.pull_request)' .
skips '.comment.body |= sub("Didn.t find any major issues"; "Found 2 issues")' .
skips '.comment.body |= sub("<!-- codex-review-receipt:v1 -->"; "")' .
skips '.comment.body |= sub("\\*\\*Reviewed commit:\\*\\* `4cdb814d89`"; "")' .
skips . '.head.sha = "b805158c46aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
skips . '.state = "closed"'
skips . '.head.repo.full_name = "fork/r"'
skips . '.head.repo = null'
skips . '.number = 8'
errors '.head.sha = null'
errors . '{"number": 7, "state": "op'
echo "codex_ok.sh ok"
