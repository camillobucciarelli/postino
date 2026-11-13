#!/bin/bash
# Self-check of rerun.sh, run by ci.yml, with a stub `gh`: only runs stopped by the gate are restarted, a job still
# in its gate is waited for, a running run is cancelled before the rerun, and runs are found by branch and commit.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin"
# Stub: `run list` prints $dir/id; each `run view` takes the next line of $dir/states (the last one repeats) and
# applies the --jq filter; cancel and rerun are logged to $dir/calls.
cat > "$dir/bin/gh" << EOF
#!/bin/bash
case "\$1 \$2" in
  "run list")
    [ "\$*" = "run list -R o/r --workflow ci.yml --event pull_request --branch feat/x --commit $(printf 'a%.0s' {1..40}) --limit 1 --json databaseId --jq .[0].databaseId // empty" ] \
      || { echo "unexpected gh \$*" >&2; exit 3; }
    cat "$dir/id" ;;
  "run view")
    state=\$(head -1 "$dir/states")
    [ "\$(wc -l < "$dir/states")" -le 1 ] || sed -i.bak 1d "$dir/states"
    jq -r "\${@: -1}" <<< "\$state" ;;
  "run cancel" | "run rerun") echo "\$1 \$2 \$5" >> "$dir/calls" ;;
  *) echo "unexpected gh \$*" >&2; exit 3 ;;
esac
EOF
chmod +x "$dir/bin/gh"

sha=$(printf 'a%.0s' {1..40})
job() { # job <status> <conclusion> <gate step conclusion or ""> [name, default check]
  jq -nc --arg s "$1" --arg c "$2" --arg g "$3" --arg n "${4:-check}" \
    '{name: $n, status: $s, conclusion: (if $c == "" then null else $c end),
      steps: (if $g == "" then [] else [{name: "Codex gate", conclusion: $g}] end)}'
}
run() { jq -nc --arg s "$1" '{status: $s, jobs: $ARGS.positional}' --jsonargs "${@:2}"; }
# expect <expected calls> <states...>
expect() {
  local want=$1; shift
  echo 42 > "$dir/id"; printf '%s\n' "$@" > "$dir/states"; : > "$dir/calls"
  PATH="$dir/bin:$PATH" REPO=o/r WAIT_SECONDS=0 tool/ci/rerun.sh "$sha" feat/x > /dev/null
  [ "$(paste -sd, "$dir/calls")" = "$want" ] || { echo "rerun.sh on $*: calls '$(paste -sd, "$dir/calls")', want '$want'"; exit 1; }
}

gated=$(job completed failure failure)
built=$(job completed success success)
broken=$(job completed failure success)
expect 'run rerun 42' "$(run completed "$gated" "$gated" "$gated")"
expect '' "$(run completed "$built" "$built" "$built")"
expect '' "$(run completed "$broken" "$built" "$built")"
# mutation has no gate: its real failure, or its long run, never restarts anything.
expect '' "$(run completed "$built" "$built" "$built" "$(job completed failure '' mutation)")"
expect '' "$(run in_progress "$built" "$built" "$built" "$(job in_progress '' '' mutation)")"
expect '' "$(run queued "$(job queued '' '')" "$(job queued '' '')")"
expect 'run cancel 42,run rerun 42' "$(run in_progress "$gated" "$(job queued '' '')")" "$(run completed "$gated" "$(job completed cancelled '')")"
# A job inside its gate is waited for: it fails on comments read before the approval, then the run is restarted.
expect 'run cancel 42,run rerun 42' "$(run in_progress "$(job in_progress '' '')" "$(job queued '' '')")" \
  "$(run in_progress "$gated" "$(job queued '' '')")" "$(run completed "$gated" "$(job completed cancelled '')")"
# ...or it passes on the approval and nothing is restarted.
expect '' "$(run in_progress "$(job in_progress '' '')")" "$(run in_progress "$(job in_progress '' success)")"
: > "$dir/id"; : > "$dir/calls"
PATH="$dir/bin:$PATH" REPO=o/r tool/ci/rerun.sh "$sha" feat/x > /dev/null
[ ! -s "$dir/calls" ] || { echo "rerun.sh without a run restarted something"; exit 1; }
echo "rerun.sh ok"
