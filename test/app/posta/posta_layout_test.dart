// The Posta layout reads its URI: /posta is the list alone, a child route opens its Conversazione beside it.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('/posta shows the list alone; opening a row opens its Conversazione beside it', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('m1', subject: 'Cena', isRead: true));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    // Routefly keeps the last navigation in statics.
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('row-a1-m1')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);
    expect(find.byKey(const ValueKey('row-a1-m1')), findsOneWidget, reason: 'the list stays beside it');
  });
}
