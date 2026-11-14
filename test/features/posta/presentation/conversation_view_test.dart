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

  testWidgets('the thread fades in once it is there, from nothing to whole (#283)', (tester) async {
    final seen = (await _openAndWatch(tester)).nonNulls.toList();
    expect(seen.first, lessThan(1), reason: 'it does not pop in');
    expect(seen.any((o) => o > 0 && o < 1), isTrue, reason: 'half way it is partly there');
    expect(_threadOpacity(tester), 1);
  });

  testWidgets('with reduced motion the thread is there at once', (tester) async {
    final seen = (await _openAndWatch(tester, reduced: true)).nonNulls.toList();
    expect(seen, isNotEmpty);
    expect(seen, everyElement(1));
  });
}

/// The opacity of the thread's fade-in (#283) at this frame; null while the thread is not there.
double? _threadOpacity(WidgetTester tester) {
  final thread = find.byKey(const ValueKey('thread'));
  if (thread.evaluate().isEmpty) return null;
  final fade = find.ancestor(of: thread, matching: find.byType(FadeTransition)).first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

/// Opens a Conversazione beside the list and returns the thread's opacity at each frame of the opening.
Future<List<double?>> _openAndWatch(WidgetTester tester, {bool reduced = false}) async {
  tester.view
    ..physicalSize = const Size(1200, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final h = await Harness.create();
  (await h.addAccount('a1')).deliver(msg('m1', conversationId: 't', date: _day(1)));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('row-a1-m1')));
  final seen = <double?>[];
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    seen.add(_threadOpacity(tester));
  }
  await tester.pumpAndSettle();
  return seen;
}
