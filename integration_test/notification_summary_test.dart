// Cold start from the summary «N nuovi messaggi» (#210), its own file so the router starts fresh. Run on an iOS
// simulator and an Android emulator.
//
// What this verifies: the app started by the summary's tap opens the Account's inbox, with real frames and the real
// router, and Indietro (the system's, Android) goes to the Posta unificata.
//
// What QA must still verify by hand: receive more than 10 messages in one sync, close the app, tap the summary.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../test/support/fake_mail_provider.dart';
import '../test/support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final mobile = !kIsWeb && {TargetPlatform.iOS, TargetPlatform.android}.contains(defaultTargetPlatform);

  testWidgets("the summary's cold launch opens the Account's inbox; Indietro goes to the Posta unificata", (
    tester,
  ) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('a', subject: 'Dal riepilogo'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp(launch: AccountTarget('a1'))));
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.path, routePaths.posta.$accountId.path.changes({'accountId': 'a1'}));
    expect(find.text('Dal riepilogo'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.path, routePaths.posta.path);
    expect(find.text('Posta unificata'), findsOneWidget);
  }, skip: !mobile);
}
