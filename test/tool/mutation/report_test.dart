import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mutation/report.dart';

// Shaped like the xunit report of mutation_test 1.8.1.
const _xunit = '''
<?xml version="1.0"?>
<testsuites>
  <testsuite id="2" name="eq" package="eq" tests="2" failures="1" errors="0" time="3.2">
    <testcase name="Line48_eq_0" classname="lib/b.dart" time="1.6"/>
    <testcase name="Line12_eq_0" classname="lib/a.dart" time="1.6"><failure type="undetected" message="All tests passed despite changing the code!">
File: lib/a.dart
Line: 12
Original line:   if (a &lt;= b &amp;&amp; c == &apos;x&apos;) return;
Mutation:   if (a &lt;= b &amp;&amp; c != &apos;x&apos;) return;
</failure></testcase>
  </testsuite>
  <testsuite id="9" name="sub" package="sub" tests="2" failures="0" errors="2" time="9">
    <testcase name="Line3_sub_0" classname="lib/a.dart" time="120"><error type="timeout" message="The test command timed out after 120 s">
File: lib/a.dart
Line: 3
Original line: x - 1
Mutation: x + 1
</error></testcase>
    <testcase name="Line7_sub_0" classname="lib/a.dart" time="0"><error type="not covered by tests" message="The line is not covered by tests">
File: lib/a.dart
Line: 7
Original line: y - 1
Mutation: y + 1
</error></testcase>
  </testsuite>
</testsuites>
''';

void main() {
  final mutants = parseXunit(_xunit);

  test('every testcase is a mutant, sorted by file and line, with its outcome and lines', () {
    expect(
      [for (final m in mutants) '${m.file}:${m.line} ${m.rule} ${m.outcome.name}'],
      [
        'lib/a.dart:3 sub timeout',
        'lib/a.dart:7 sub notCovered',
        'lib/a.dart:12 eq survived',
        'lib/b.dart:48 eq killed',
      ],
    );
    expect(mutants[2].original, "if (a <= b && c == 'x') return;");
    expect(mutants[2].mutated, "if (a <= b && c != 'x') return;");
  });

  test('the score counts killed and timed out mutants over all of them', () {
    expect(score(mutants), 50);
    expect(score([]), isNull);
  });

  test('the report lists survivors and the files it could not measure', () {
    final report = renderReport(
      results: [
        (file: 'lib/a.dart', tests: ['test/a_test.dart'], mutants: mutants.sublist(0, 3)),
      ],
      threshold: 0,
      withoutTests: ['lib/c.dart'],
      tooManyTests: ['lib/main.dart (70 test)'],
      redBaseline: [],
      errors: [],
      sampling: '3 mutanti su 9 candidati',
    );
    expect(report, contains('**Punteggio 33.3%** su 3 mutanti'));
    expect(report, contains('| `lib/a.dart` | 1 | 0 | 1 | 1 | 1 | 33.3% |'));
    expect(report, contains("| `lib/a.dart:12` | eq | `if (a <= b && c == 'x') return;` |"));
    expect(report, contains('**Senza test corrispondente** (1):'));
    expect(report, contains('**Importati da troppi test, non misurati** (1):'));
    expect(report, contains('Campionamento: 3 mutanti su 9 candidati'));
    expect(report, isNot(contains('Errori dello strumento')));
  });
}
