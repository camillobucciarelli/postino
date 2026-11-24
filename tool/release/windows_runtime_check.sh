#!/bin/bash
# Fails when an .exe or .dll in <dir> (the Windows build's Release folder) needs a DLL of the Visual C++ runtime
# (msvcp*, vcruntime*, concrt*, vcomp*, vccorlib*) that is not in <dir>: on a PC without the Visual C++ Redistributable
# the app would not start. The hosted runner has the runtime installed, so a green build alone does not prove it.
# Usage: windows_runtime_check.sh <dir>   (DUMPBIN overrides the dumpbin found through vswhere, for the self-check)
set -euo pipefail
dir=${1:?usage: windows_runtime_check.sh <dir>}

if [ -z "${DUMPBIN:-}" ]; then
  vs=$("${ProgramFiles(x86):-C:/Program Files (x86)}/Microsoft Visual Studio/Installer/vswhere.exe" -latest -products '*' \
    -property installationPath | tr -d '\r')
  DUMPBIN=$(ls "$vs"/VC/Tools/MSVC/*/bin/Hostx64/x64/dumpbin.exe | tail -n 1)
fi

missing=0
checked=0
for bin in "$dir"/*.exe "$dir"/*.dll; do
  [ -e "$bin" ] || continue
  # dumpbin lists each dependency alone on an indented line; a dumpbin failure fails the check (pipefail).
  deps=$("$DUMPBIN" /nologo /dependents "$bin" | tr -d '\r' | sed -n 's/^ *\([^ ]*\.[dD][lL][lL]\)$/\1/p')
  checked=$((checked + 1))
  for dep in $deps; do
    case "$(tr '[:upper:]' '[:lower:]' <<< "$dep")" in
      msvcp* | vcruntime* | concrt* | vcomp* | vccorlib*)
        test -e "$dir/$dep" || { echo "::error::${bin##*/} needs $dep, not in $dir"; missing=1; }
        ;;
    esac
  done
done
test "$checked" -gt 0 || { echo "::error::No .exe or .dll in $dir"; exit 1; }
test "$missing" = 0 && echo "Visual C++ runtime bundled: $checked binaries checked"
exit "$missing"
