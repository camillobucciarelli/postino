import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/features/segnalazione/domain/problem_report_config.dart';
import 'package:postino/features/segnalazione/domain/report_problem_use_case.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

Future<OutgoingMessage> _saved((String, String) draft) async =>
    ((await getIt<MailSync>().openDraft(draft.$1, draft.$2)) as Ok<OutgoingMessage>).value;

void main() {
  late Harness h;

  setUp(() async => h = await Harness.create());

  test('with an Account the log, escaped, goes in a Bozza to the author from the first Account', () async {
    await h.addAccount('a2');
    await h.addAccount('a1');
    h.errorLog.record('<b>boom</b>');
    await Future<void>.delayed(Duration.zero);

    final draft = await getIt<ReportProblemUseCase>().start(subject: 'S', intro: 'Intro');

    expect(draft!.$1, 'a2');
    final m = await _saved(draft);
    expect(m.to, [problemReportAddress]);
    expect(m.from, 'a2@example.com');
    expect(m.subject, 'S');
    expect(m.body, contains('&lt;b&gt;boom&lt;/b&gt;'));
    expect(m.body, startsWith('<p>Intro</p>'));
    expect(h.sharer.shared, isEmpty);
  });

  test('a long log is cut to its latest entries in the Bozza, and whole in the shared file', () async {
    // Entries are capped at 8 KB each: many of them make the long log.
    for (var i = 0; i < 10; i++) {
      h.errorLog.record('a' * 6000);
    }
    h.errorLog.record('FINE');
    await Future<void>.delayed(Duration.zero);

    await getIt<ReportProblemUseCase>().start(subject: 'S', intro: 'I');
    expect(h.sharer.shared.single.$1.length, greaterThan(ReportProblemUseCase.maxBodyChars));

    await h.addAccount('a1');
    final draft = await getIt<ReportProblemUseCase>().start(subject: 'S', intro: 'I');
    final m = await _saved(draft!);
    // Cut at a line start: the first line left starts an entry (its timestamp).
    expect(m.body, contains('<pre>…2026-'));
    expect(m.body, endsWith('FINE</pre>'));
    expect(m.body.length, lessThan(ReportProblemUseCase.maxBodyChars + 200));
  });

  test('without an Account the log is shared and there is no Bozza', () async {
    h.errorLog.record('boom');
    await Future<void>.delayed(Duration.zero);

    expect(await getIt<ReportProblemUseCase>().start(subject: 'S', intro: 'I'), isNull);
    expect(h.sharer.shared.single.$2, problemReportFileName);
  });
}
