// Cold start from the summary «N nuovi messaggi» (#210): its own file, so routefly's statics are fresh as in a real
// launch.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import 'notification_steps.dart';

void main() {
  testWidgets("launched by a tap on the summary, the Account's inbox opens; Indietro goes to the Posta unificata", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    (await h.addAccount(notifiedAccount)).deliver(msg('a', subject: 'Primo'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp(launch: AccountTarget(notifiedAccount))));
    await tester.pumpAndSettle();

    expect(Routefly.currentUri.path, routePaths.posta.$accountId.path.changes({'accountId': notifiedAccount}));
    expect(find.text('Primo'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectUnified();
  });
}
