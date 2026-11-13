#!/bin/bash
# Restarts ci.yml's pull_request run of a PR head after an approval (#246), so its Codex gate reads the approval.
# Only jobs stopped by the gate count: a real test failure is not restarted.
# - A job still before or inside its gate step may be reading comments from before the approval: wait for it.
# - No job failed at the gate: nothing (jobs not started yet read the approval themselves).
# - Some job failed at the gate: cancel the run if still going, then rerun it whole.
# Reruns keep the PR association, so the ruleset counts their checks. Used by codex-ok.yml; by hand too.
# Env: REPO (owner/name), GH_TOKEN or a gh login with actions: write; WAIT_SECONDS (default 5).
# Usage: rerun.sh <head sha> <head branch>
set -euo pipefail
sha=${1:?usage: rerun.sh <head sha> <head branch>}
branch=${2:?usage: rerun.sh <head sha> <head branch>}
[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "not a full sha: $sha" >&2; exit 2; }
pause=${WAIT_SECONDS:-5}

# The branch tells apart two PRs whose heads are the same commit.
id=$(gh run list -R "$REPO" --workflow ci.yml --event pull_request --branch "$branch" --commit "$sha" --limit 1 \
  --json databaseId --jq '.[0].databaseId // empty')
[ -n "$id" ] || { echo "no pull_request run of ci.yml for $branch at $sha"; exit 0; }

# Only the gated jobs: a mutation failure is real, never a gate stop.
gated='(.name == "check" or .name == "android" or .name == "apple")'
gate='any(.steps[]?; .name == "Codex gate" and .conclusion == "success")'
# Prints "<run status> <jobs failed at the gate> <jobs still before or in the gate>".
state() {
  gh run view -R "$REPO" "$id" --json status,jobs --jq "[.status,
    ([.jobs[] | select($gated and .conclusion == \"failure\" and ($gate | not))] | length),
    ([.jobs[] | select($gated and .status == \"in_progress\" and ($gate | not))] | length)] | join(\" \")"
}
for _ in $(seq 60); do
  read -r status failed gating <<< "$(state)"
  [ "$gating" -gt 0 ] || break
  sleep "$pause"
done
[ "$gating" -eq 0 ] || { echo "run $id: jobs still in the gate, rerun it by hand" >&2; exit 1; }
[ "$failed" -gt 0 ] || { echo "run $id $status: no job stopped by the gate"; exit 0; }

if [ "$status" != completed ]; then
  gh run cancel -R "$REPO" "$id"
  for _ in $(seq 60); do
    read -r status failed gating <<< "$(state)"
    [ "$status" = completed ] && break
    sleep "$pause"
  done
fi
gh run rerun -R "$REPO" "$id"
echo "run $id restarted"
