// The open Conversazione (the twin of conversation_view.dart for the mutation test): which tap on a message reads
// the Conversazione. The rest of its behaviour is in conversation_test.dart.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

Finder _message(String id) => find.byKey(ValueKey('message-$id'));

bool _expanded(WidgetTester tester, String id) => tester.widget<PostinoThreadMessage>(_message(id)).expanded;

void main() {
  testWidgets(
    'off screen, expanding a read message does not read the unread one that arrived; expanding that one does',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create();
      final gmail = await h.addAccount('a1');
      gmail
        ..deliver(msg('m1', conversationId: 't', snippet: 'Venerdì?', date: _day(1), isRead: true))
        ..deliver(msg('m2', conversationId: 't', date: _day(2), isRead: true))
        ..deliver(msg('m3', conversationId: 't', date: _day(3)));
      LocaleSettings.setLocaleSync(AppLocale.it);
      await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
      // Routefly keeps the last navigation in statics.
      unawaited(Routefly.navigate(routePaths.posta.path));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('row-a1-m3')));
      await tester.pumpAndSettle();
      List<(String, bool)> readCalls() => [for (final (ids, read) in gmail.readCalls) (ids.join(','), read)];
      expect(readCalls(), [('m3', true)]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      gmail.deliver(msg('m4', conversationId: 't', date: _day(7)));
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm4'), isTrue);
      expect(readCalls(), isNot(contains(('m4', true))), reason: 'off screen: still unread');

      await tester.tap(find.text('Venerdì?'));
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm1'), isTrue);
      expect(readCalls(), isNot(contains(('m4', true))), reason: 'the message tapped was already read');

      final avatar = find.descendant(of: _message('m4'), matching: find.byType(PostinoAvatar));
      // Collapsed and expanded again, the unread one is read by the opening.
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm4'), isFalse);
      expect(readCalls(), isNot(contains(('m4', true))));
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm4'), isTrue);
      expect(readCalls(), contains(('m4', true)));
    },
  );
}
