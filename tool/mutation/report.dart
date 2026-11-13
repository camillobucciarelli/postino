/// The mutants of a `mutation_test` xunit report and the Markdown summary of a run
/// (docs/agents/mutation-test.md).
library;

enum Outcome() {
  killed,
  survived,
  timeout,
  notCovered,
}

typedef Mutant = ({String file, int line, String rule, Outcome outcome, String original, String mutated});

/// One file of the run: its tests and its mutants.
typedef FileResult = ({String file, List<String> tests, List<Mutant> mutants});

final _testcase = RegExp(
  r'<testcase name="Line(\d+)_(.+?)_\d+" classname="([^"]*)"[^>]*?(?:/>|>(.*?)</testcase>)',
  dotAll: true,
);

/// The mutants in [xunit], the report `mutation_test -f xunit` writes, sorted by file and line.
List<Mutant> parseXunit(String xunit) {
  String field(String body, String name) =>
      _unescape(RegExp('^$name: (.*)\$', multiLine: true).firstMatch(body)?.group(1)?.trim() ?? '');
  return [
    for (final m in _testcase.allMatches(xunit))
      (
        file: m.group(3)!,
        line: int.parse(m.group(1)!),
        rule: m.group(2)!,
        outcome: switch (m.group(4) ?? '') {
          final b when b.contains('type="undetected"') => Outcome.survived,
          final b when b.contains('type="timeout"') => Outcome.timeout,
          final b when b.contains('type="not covered by tests"') => Outcome.notCovered,
          _ => Outcome.killed,
        },
        original: field(m.group(4) ?? '', 'Original line'),
        mutated: field(m.group(4) ?? '', 'Mutation'),
      ),
  ]..sort((a, b) => a.file == b.file ? a.line.compareTo(b.line) : a.file.compareTo(b.file));
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// The share of [mutants] the tests catch, in percent: killed and timed out over all (an uncovered mutant
/// survives by definition). Null without mutants.
double? score(Iterable<Mutant> mutants) {
  final all = mutants.length;
  if (all == 0) return null;
  final caught = mutants.where((m) => m.outcome == Outcome.killed || m.outcome == Outcome.timeout).length;
  return caught * 100 / all;
}

/// The Markdown report of a run: totals against [threshold], a row per file, every surviving and uncovered
/// mutant, and the files the run could not measure.
String renderReport({
  required List<FileResult> results,
  required double threshold,
  required List<String> withoutTests,
  List<String> tooManyTests = const [],
  required List<String> redBaseline,
  required List<String> errors,
  String? sampling,
}) {
  final all = [for (final r in results) ...r.mutants];
  String pct(double? v) => v == null ? '–' : '${v.toStringAsFixed(1)}%';
  int count(List<Mutant> ms, Outcome o) => ms.where((m) => m.outcome == o).length;
  String code(String s) => '`${s.trim().replaceAll('`', "'").replaceAll('|', r'\|')}`';
  final out = StringBuffer()
    ..writeln('## Mutation test')
    ..writeln()
    ..writeln(
      '**Punteggio ${pct(score(all))}** su ${all.length} mutanti (soglia ${pct(threshold)}): '
      '${count(all, Outcome.killed)} uccisi, ${count(all, Outcome.survived)} sopravvissuti, '
      '${count(all, Outcome.notCovered)} non coperti, ${count(all, Outcome.timeout)} timeout.',
    );
  if (sampling != null) {
    out
      ..writeln()
      ..writeln('Campionamento: $sampling');
  }
  if (results.isNotEmpty) {
    out
      ..writeln()
      ..writeln('| File | Test | Uccisi | Sopravvissuti | Non coperti | Timeout | Punteggio |')
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: |');
    for (final r in results) {
      final ms = r.mutants;
      out.writeln(
        '| `${r.file}` | ${r.tests.length} | ${count(ms, Outcome.killed)} | ${count(ms, Outcome.survived)} | '
        '${count(ms, Outcome.notCovered)} | ${count(ms, Outcome.timeout)} | ${pct(score(ms))} |',
      );
    }
  }
  for (final (title, outcome) in [('Sopravvissuti', Outcome.survived), ('Non coperti dai test', Outcome.notCovered)]) {
    final ms = all.where((m) => m.outcome == outcome).toList();
    if (ms.isEmpty) continue;
    out
      ..writeln()
      ..writeln('<details><summary>$title (${ms.length})</summary>')
      ..writeln()
      ..writeln('| Riga | Regola | Originale | Mutante |')
      ..writeln('| --- | --- | --- | --- |');
    for (final m in ms) {
      out.writeln('| `${m.file}:${m.line}` | ${m.rule} | ${code(m.original)} | ${code(m.mutated)} |');
    }
    out
      ..writeln()
      ..writeln('</details>');
  }
  for (final (title, files) in [
    ('Senza test corrispondente', withoutTests),
    ('Importati da troppi test, non misurati', tooManyTests),
    ('Test già rossi prima delle mutazioni (non misurati)', redBaseline),
    ('Errori dello strumento', errors),
  ]) {
    if (files.isEmpty) continue;
    out
      ..writeln()
      ..writeln('**$title** (${files.length}):')
      ..writeln();
    for (final f in files) {
      out.writeln('- `$f`');
    }
  }
  return out.toString();
}
