#!/bin/sh
# Compila litehtml come hook/build.dart (-O3) e lancia stack_test.cpp: i limiti di annidamento
# devono reggere su uno stack di 256 KB (ADR 0025). Richiede clang (Xcode sul runner macOS).
set -eu
pkg=$(cd "$(dirname "$0")/../.." && pwd)
lh=$pkg/third_party/litehtml
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
inc="-I$lh/include -I$lh/include/litehtml -I$lh/src/gumbo/include -I$lh/src/gumbo/include/gumbo -I$pkg/src"

for f in "$lh"/src/gumbo/*.c; do
  echo "clang -std=c99 -w -O3 $inc -c $f -o $out/gumbo_$(basename "$f").o"
done >"$out/jobs"
for f in "$lh"/src/*.cpp "$pkg/src/litehtml_c.cpp"; do
  echo "clang++ -std=c++17 -w -O3 $inc -c $f -o $out/$(basename "$f").o"
done >>"$out/jobs"
# Una riga per compilazione, in parallelo.
xargs -P 8 -L 1 sh -c '"$0" "$@"' <"$out/jobs"

clang++ -std=c++17 -O3 $inc "$pkg/test/native/stack_test.cpp" "$out"/*.o -o "$out/stack_test"
"$out/stack_test"
