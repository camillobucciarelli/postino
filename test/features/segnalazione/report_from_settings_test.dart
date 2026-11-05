// Segnala un problema (#117) from the Impostazioni: a Bozza to the author with the log, nothing sent.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/segnalazione/domain/problem_report_config.dart';
import 'package:routefly/routefly.dart';

import 'report_steps.dart';

void main() {
  testWidgets('with an Account, the Impostazioni open a Bozza to the author with the log; nothing is sent', (
    tester,
  ) async {
    await start(tester);
    await fromSettings(tester);

    expect(Routefly.currentUri.pathSegments[2], 'bozza');
    expect(fieldText(tester, 'A'), problemReportAddress);
    expect(fieldText(tester, 'Oggetto'), 'Problema in Postino');
    expect(find.textContaining('boom', findRichText: true), findsOneWidget);
    expect(h.sharer.shared, isEmpty);
    expect(gmail.sent, isEmpty);
    await close(tester);
  });
}
