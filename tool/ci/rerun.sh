#!/bin/bash
# Restarts ci.yml's pull_request run of a PR head after an approval (#246), so its Codex gate reads the approval:
# - finished without success: rerun it;
# - still running, with a job already failed (the gate before the approval): cancel, wait, rerun;
# - still queued or running with no failure: nothing, the jobs not started yet will read the approval themselves.
# Reruns keep the PR association, so the ruleset counts their checks. Used by codex-ok.yml; by hand too.
# Env: REPO (owner/name), GH_TOKEN or a gh login with actions: write. Usage: rerun.sh <head sha>
set -euo pipefail
sha=${1:?usage: rerun.sh <head sha>}
[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "not a full sha: $sha" >&2; exit 2; }

run=$(gh run list -R "$REPO" --workflow ci.yml --event pull_request --commit "$sha" --limit 1 \
  --json databaseId,status,conclusion --jq '.[0] // empty | "\(.databaseId) \(.status) \(.conclusion)"')
[ -n "$run" ] || { echo "no pull_request run of ci.yml for $sha"; exit 0; }
read -r id status conclusion <<< "$run"

if [ "$status" != completed ]; then
  failed=$(gh run view -R "$REPO" "$id" --json jobs --jq '[.jobs[] | select(.conclusion == "failure")] | length')
  [ "$failed" -gt 0 ] || { echo "run $id $status: its jobs will read the approval"; exit 0; }
  gh run cancel -R "$REPO" "$id"
  for _ in $(seq 60); do
    [ "$(gh run view -R "$REPO" "$id" --json status --jq .status)" = completed ] && break
    sleep 5
  done
elif [ "$conclusion" = success ]; then
  echo "run $id already green"; exit 0
fi
gh run rerun -R "$REPO" "$id"
echo "run $id restarted"
