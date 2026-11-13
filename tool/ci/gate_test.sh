#!/bin/bash
# Self-check of gate.sh and approved.sh, run by ci.yml, with a stub `gh`: the gate opens only on Codex's ok or on
# `ci-ok` from a user with write access read from the API, and never on a pull_request run otherwise.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin"
# Stub: the comments come from $dir/comments.json, the permission of <login> from $dir/perm.<login> (missing = 404).
cat > "$dir/bin/gh" << EOF
#!/bin/bash
case "\$*" in
  "api --paginate repos/o/r/issues/7/comments") cat "$dir/comments.json" ;;
  "api repos/o/r/collaborators/"*"/permission --jq .permission")
    login=\${2#repos/o/r/collaborators/}; login=\${login%/permission}
    cat "$dir/perm.\$login" 2> /dev/null || { echo "HTTP 404" >&2; exit 1; } ;;
  *) echo "unexpected gh \$*" >&2; exit 3 ;;
esac
EOF
chmod +x "$dir/bin/gh"

head=4cdb814d898b3b3c22f464f39d8cae61a8a7b5cd
receipt=$'<!-- codex-review-receipt:v1 -->\n\nCodex Review: Didn\'t find any major issues.\n\n**Reviewed commit:** `4cdb814d89`\n'
user() { jq -n --arg b "$1" --arg l "$2" '{body: $b, user: {login: $l, type: "User"}}'; }
codex() { jq -n --arg b "$receipt" '{body: $b, user: {login: "chatgpt-codex-connector[bot]", type: "Bot"}}'; }
# gate <expected rc> <event> <comment objects...>
gate() {
  local want=$1 event=$2; shift 2
  printf '%s\n' "$@" | jq -s . > "$dir/comments.json"
  local rc=0
  PATH="$dir/bin:$PATH" EVENT=$event REPO=o/r PR=7 HEAD_SHA=$head tool/ci/gate.sh > /dev/null 2>&1 || rc=$?
  [ "$rc" -eq "$want" ] || { echo "gate.sh ($event, $*): rc=$rc, want $want"; exit 1; }
}

echo write > "$dir/perm.writer"
echo admin > "$dir/perm.owner"
echo read > "$dir/perm.reader"
gate 0 push
gate 0 workflow_dispatch
gate 1 pull_request
gate 1 pull_request "$(user '@codex review' writer)"
gate 0 pull_request "$(codex)"
gate 0 pull_request "$(user 'ci-ok 4cdb814' writer)"
gate 0 pull_request "$(user 'ci-ok 4cdb814' owner)"
gate 1 pull_request "$(user 'ci-ok 4cdb814' reader)"
gate 0 pull_request "$(user 'ci-ok 4cdb814' reader)" "$(user 'ci-ok 4cdb814d89' writer)"
gate 1 pull_request "$(user 'ci-ok b805158' writer)"
gate 2 pull_request "$(user 'ci-ok 4cdb814' stranger)"
gate 1 pull_request "$(codex | jq '.body |= sub("4cdb814d89"; "b805158c46")')"
echo "gate.sh ok"
