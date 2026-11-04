// Cold start from a notification (#39): its own file, so routefly's statics are fresh as in a real launch.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import 'notification_steps.dart';

void main() {
  testWidgets('launched by a tap on a notification, the Conversazione opens; Indietro goes to the Posta unificata', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    (await h.addAccount(notifiedAccount)).deliver(msg('a', subject: 'Primo'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(
      TranslationProvider(child: const PostinoApp(launch: (accountId: notifiedAccount, conversationId: 't-a'))),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');
    await tapBack(tester);
    expectUnified();
  });
}
