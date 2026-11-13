import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mutation/targets.dart';

void main() {
  test('only hand-written Dart under lib/ is mutated', () {
    expect(isMutable('lib/core/domain/reply.dart'), isTrue);
    expect(isMutable('lib/core/data/daos/messages_dao.g.dart'), isFalse);
    expect(isMutable('lib/main.config.dart'), isFalse);
    expect(isMutable('lib/main.route.dart'), isFalse);
    expect(isMutable('test/core/domain/reply_test.dart'), isFalse);
    expect(isMutable('lib/core/domain/analysis_options.yaml'), isFalse);
  });

  test('the twin test wins, otherwise every test that imports the file', () {
    final tests = {
      'test/core/domain/reply_test.dart': "import 'package:postino/core/domain/reply.dart';",
      'test/features/a_test.dart': "import 'package:postino/core/domain/reply.dart';",
      'test/features/c_test.dart': "import 'package:postino/core/domain/message.dart';",
      'test/features/b_test.dart': "import 'package:postino/core/domain/message.dart';",
      'test/architecture_test.dart': "const paths = [\n  'package:postino/core/domain/message.dart',\n];",
    };
    expect(testsFor('lib/core/domain/reply.dart', tests), ['test/core/domain/reply_test.dart']);
    expect(testsFor('lib/core/domain/message.dart', tests), ['test/features/b_test.dart', 'test/features/c_test.dart']);
    expect(testsFor('lib/core/domain/mail.dart', tests), isEmpty);
  });

  test('the sample takes one line every ceil(n / budget), the same on every run, never over budget', () {
    // a.dart: lines 1..5 with one mutant each; b.dart: line 6 with three, lines 7..8 with one.
    final mutants = [
      for (var i = 1; i <= 5; i++) (file: 'a.dart', line: i),
      for (var i = 0; i < 3; i++) (file: 'b.dart', line: 6),
      (file: 'b.dart', line: 7),
      (file: 'b.dart', line: 8),
    ];
    expect(sampleLines(mutants, 0), isNull);
    expect(sampleLines(mutants, 10), isNull);
    // step 2 over the 8 distinct lines: 1, 3, 5, 7; b.dart:6 (three mutants) is never picked.
    expect(sampleLines(mutants, 5), {
      'a.dart': {1, 3, 5},
      'b.dart': {7},
    });
    // step 4: lines 1 and 5.
    expect(sampleLines(mutants, 3), {
      'a.dart': {1, 5},
    });
    // step 3 over 4 distinct lines: a.dart:1, then b.dart:6 whose four mutants would go over 3.
    expect(sampleLines([...mutants.take(3), for (var i = 0; i < 4; i++) (file: 'b.dart', line: 6)], 3), {
      'a.dart': {1},
    });
  });
}
