#!/bin/bash
# Self-check of r2_unreleased.sh, run by ci.yml, against a local HTTP server standing in for R2: a missing object
# or a manual run's build lets the tag release go on; a tag release's object (immutable), a refusal of the bucket
# or a bucket that cannot be reached stops it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fails() { if "$@" > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }

# HEAD /bucket/<key>: "tag" -> 200 immutable, "manual" -> 200 max-age=300, "denied" -> 403, anything else -> 404.
port=$(python3 -I -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -I - "$port" > /dev/null 2>&1 <<'EOF' &
import http.server, sys
answers = {"tag": (200, "public, max-age=31536000, immutable"), "manual": (200, "public, max-age=300"), "denied": (403, None)}
class R2(http.server.BaseHTTPRequestHandler):
    def do_HEAD(self):
        status, cache = answers.get(self.path.rsplit("/", 1)[-1], (404, None))
        self.send_response(status)
        if cache:
            self.send_header("Cache-Control", cache)
        self.end_headers()
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), R2).serve_forever()
EOF
server=$!
trap 'kill "$server" 2> /dev/null || true' EXIT
for _ in $(seq 50); do curl --silent --head --output /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done

export R2_ACCESS_KEY_ID=test R2_SECRET_ACCESS_KEY=test R2_ACCOUNT_ID=test R2_BUCKET=bucket
export R2_ENDPOINT="http://127.0.0.1:$port"
tool/release/r2_unreleased.sh macos/1.0.1/missing > /dev/null
tool/release/r2_unreleased.sh macos/1.0.1/manual > /dev/null
fails tool/release/r2_unreleased.sh macos/1.0.0/tag
fails tool/release/r2_unreleased.sh macos/1.0.0/denied
kill "$server"
wait "$server" 2> /dev/null || true
fails tool/release/r2_unreleased.sh macos/1.0.1/missing
echo "r2_unreleased.sh ok"
