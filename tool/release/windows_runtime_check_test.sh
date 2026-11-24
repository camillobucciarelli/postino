#!/bin/bash
# Self-check of windows_runtime_check.sh, run by ci.yml: a stub dumpbin prints canned dependencies; the check passes
# only when every Visual C++ runtime DLL needed is in the folder, and fails on an empty folder or a failing dumpbin.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/app"
dumpbin="$tmp/dumpbin"
printf '#!/bin/bash\ncat <<EOF\n\nDump of file $2\n\nFile Type: DLL\n\n  Image has the following dependencies:\n\n    flutter_windows.dll\n    MSVCP140.dll\n    VCRUNTIME140.dll\n    KERNEL32.dll\n\n  Summary\n\n        1000 .data\nEOF\n' > "$dumpbin"
chmod +x "$dumpbin"
passes() { DUMPBIN="$dumpbin" tool/release/windows_runtime_check.sh "$tmp/app" > /dev/null 2>&1 || { echo "should pass: $1"; exit 1; }; }
fails() { if DUMPBIN="$dumpbin" tool/release/windows_runtime_check.sh "$tmp/app" > /dev/null 2>&1; then echo "should fail: $1"; exit 1; fi; }

fails "empty folder"
touch "$tmp/app/postino.exe" "$tmp/app/litehtml_flutter.dll"
fails "runtime missing"
touch "$tmp/app/MSVCP140.dll"
fails "vcruntime140.dll missing"
touch "$tmp/app/VCRUNTIME140.dll"
passes "runtime bundled, system DLLs not required"
printf '#!/bin/bash\nexit 1\n' > "$dumpbin"
fails "dumpbin fails"
echo "windows_runtime_check.sh ok"
