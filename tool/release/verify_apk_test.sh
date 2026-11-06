#!/bin/bash
# Self-check of verify_apk.sh, run by ci.yml: a stub apksigner prints canned output in both formats
# (build-tools before and from 37) and a stub aapt2 prints canned badging: only the expected single signer
# with the expected versionCode and versionName passes.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/build-tools/99.0.0"
stub="$tmp/build-tools/99.0.0/apksigner"
aapt="$tmp/build-tools/99.0.0/aapt2"
want=AA:BB:CC
other=dddddd

stub_prints() { printf '#!/bin/bash\ncat <<EOF\n%s\nEOF\n' "$1" > "$stub"; chmod +x "$stub"; }
passes() { ANDROID_HOME="$tmp" tool/release/verify_apk.sh app.apk "$want" 1002003 1.2.3 > /dev/null 2>&1 || { echo "should pass: $1"; exit 1; }; }
fails() { if ANDROID_HOME="$tmp" tool/release/verify_apk.sh app.apk "$want" 1002003 1.2.3 > /dev/null 2>&1; then echo "should fail: $1"; exit 1; fi; }

aapt_prints() { printf '#!/bin/bash\necho "%s"\n' "$1" > "$aapt"; chmod +x "$aapt"; }
aapt_prints "package: name='app.postino' versionCode='1002003' versionName='1.2.3' platformBuildVersionName='16'"
stub_prints "Signer #1 certificate SHA-256 digest: aabbcc"
passes "old format"
stub_prints "V2 Signer: certificate SHA-256 digest: aabbcc
V3 Signer: certificate SHA-256 digest: aabbcc
V2 Signer: certificate SHA-1 digest: $other"
passes "build-tools 37 format, one line per scheme"
stub_prints "V2 Signer: certificate SHA-256 digest: $other"
fails "other signer"
stub_prints "Signer #1 certificate SHA-256 digest: aabbcc
Signer #2 certificate SHA-256 digest: $other"
fails "second signer"
stub_prints ""
fails "no signer"
printf '#!/bin/bash\nexit 1\n' > "$stub"
fails "apksigner verify fails"
aapt_prints "package: name='app.postino' versionCode='1' versionName='1.2.3'"
stub_prints "Signer #1 certificate SHA-256 digest: aabbcc"
fails "versionCode 1 instead of derived"
aapt_prints "package: name='app.postino' versionCode='1002003' versionName='1.2.4'"
fails "other versionName"
aapt_prints "package: name='app.postino'"
fails "no versionCode"
rm "$aapt"
fails "no aapt2"
rm "$stub"
out=$(ANDROID_HOME="$tmp" tool/release/verify_apk.sh app.apk "$want" 1002003 1.2.3 2>&1 || true)
grep -q 'No apksigner' <<< "$out" || { echo "missing apksigner: no error"; exit 1; }
echo "verify_apk.sh ok"
