#!/bin/sh
# Compila litehtml come hook/build.dart (-O3) e lancia stack_test.cpp: i limiti di annidamento
# devono reggere su uno stack di STACK_KB KB, di default 256 (ADR 0025). Richiede clang (Xcode sul
# runner macOS, il pacchetto clang su Linux).
set -eu
# float-cast-overflow: un cast float->int fuori range (z-index 2147483647, #399) è UB che su arm64
# satura e su x86_64 no; così il test cade ovunque.
san="-fsanitize=float-cast-overflow -fno-sanitize-recover=all"
kb=${STACK_KB:-256}
pkg=$(cd "$(dirname "$0")/../.." && pwd)
lh=$pkg/third_party/litehtml
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
inc="-I$lh/include -I$lh/include/litehtml -I$lh/src/gumbo/include -I$lh/src/gumbo/include/gumbo -I$pkg/src"

for f in "$lh"/src/gumbo/*.c; do
  echo "clang -std=c99 -w -O3 $inc -c $f -o $out/gumbo_$(basename "$f").o"
done >"$out/jobs"
for f in "$lh"/src/*.cpp "$pkg"/src/*.cpp; do
  echo "clang++ -std=c++17 -w -O3 $san $inc -c $f -o $out/$(basename "$f").o"
done >>"$out/jobs"
# Una riga per compilazione, in parallelo.
xargs -P 8 -L 1 sh -c '"$0" "$@"' <"$out/jobs"

clang++ -std=c++17 -O3 $san -DSTACK_KB="$kb" $inc "$pkg/test/native/stack_test.cpp" "$out"/*.o -o "$out/stack_test"
"$out/stack_test"
