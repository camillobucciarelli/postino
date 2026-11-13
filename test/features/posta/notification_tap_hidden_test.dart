// Started hidden at login (#239): the window may draw no frame until shown, so a tap on a notification is heard from
// the start, shows the window and opens its Conversazione once the Posta unificata is drawn. Its own file, so
// routefly's statics are fresh as in a real launch.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/app_window.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import 'notification_steps.dart';

class _FakeWindow() implements AppWindow {
  var shown = 0;

  @override
  Stream<void> interceptClose() => const Stream.empty();

  @override
  Future<void> show() async => shown++;

  @override
  Future<void> hide() async {}

  @override
  Future<void> quit() async {}
}

void main() {
  testWidgets('a tap before the first frame of the Posta unificata shows the window and opens the Conversazione', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    final window = _FakeWindow();
    getIt.registerSingleton<AppWindow>(window);
    (await h.addAccount(notifiedAccount)).deliver(msg('a', subject: 'Primo'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));

    h.notifications.tap(const ConversationTarget((accountId: notifiedAccount, conversationId: 't-a')));
    await tester.pumpAndSettle();

    expect(window.shown, 1);
    expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');
  });
}
