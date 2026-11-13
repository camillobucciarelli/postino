/// Which files the mutation test mutates, which tests it runs for each, and which mutants it samples
/// (docs/agents/mutation-test.md).
library;

/// The generated files, as the `Format` step of ci.yml excludes them.
final _generated = RegExp(r'\.(g|freezed|config|route)\.dart$');

/// Whether [path] (relative to the repository root) is hand-written Dart under `lib/`.
bool isMutable(String path) => path.startsWith('lib/') && path.endsWith('.dart') && !_generated.hasMatch(path);

/// The tests of [source] among [tests] (path → content): its twin `test/a/b_test.dart` for `lib/a/b.dart`,
/// otherwise every test that imports it.
List<String> testsFor(String source, Map<String, String> tests) {
  final relative = source.substring('lib/'.length);
  final twin = 'test/${relative.substring(0, relative.length - '.dart'.length)}_test.dart';
  if (tests.containsKey(twin)) return [twin];
  // An import directive, not the URI quoted as data (architecture_test.dart lists paths).
  final import = RegExp("^import 'package:postino/${RegExp.escape(relative)}'", multiLine: true);
  return [
    for (final MapEntry(:key, :value) in tests.entries)
      if (import.hasMatch(value)) key,
  ]..sort();
}

/// The lines to mutate per file when [mutants] (file and line of each candidate, sorted by file and line)
/// exceed [budget]: one distinct line every `ceil(n / budget)`, skipping a line whose mutants would go over
/// [budget], so the same code always gives the same sample and never more than [budget] mutants. Null when
/// everything fits (or [budget] is 0, no limit).
Map<String, Set<int>>? sampleLines(List<({String file, int line})> mutants, int budget) {
  if (budget <= 0 || mutants.length <= budget) return null;
  final perLine = <({String file, int line}), int>{};
  for (final m in mutants) {
    perLine[m] = (perLine[m] ?? 0) + 1;
  }
  final distinct = perLine.keys.toList();
  final step = (mutants.length + budget - 1) ~/ budget;
  final lines = <String, Set<int>>{};
  var taken = 0;
  for (var i = 0; i < distinct.length; i += step) {
    final count = perLine[distinct[i]]!;
    if (taken + count > budget) continue;
    taken += count;
    lines.putIfAbsent(distinct[i].file, () => {}).add(distinct[i].line);
  }
  return lines;
}

/// The most tests a file reaches only through imports: past it the file is shared plumbing (like `main.dart`,
/// imported by ~70 tests) and a run per mutant would take the whole suite.
const maxIndirectTests = 5;
