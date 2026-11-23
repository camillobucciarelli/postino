// Impostazioni del dispositivo › the Azioni of a notification (#211), where there is no avvio al login (iOS, Android)
// too.

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import 'device_settings_steps.dart';

Finder _choice(String place, String action) => find.byKey(ValueKey('notification-action-$place-$action'));

bool _selected(WidgetTester tester, String place, String action) =>
    tester.widget<PostinoChoiceRow>(_choice(place, action)).selected;

void main() {
  testWidgets('Archivia and Segna come letto by default; a choice is saved and the next notification has it', (
    tester,
  ) async {
    final h = await openPhoneDeviceSettings(tester);
    expect(_selected(tester, 'first', 'archive'), isTrue);
    expect(_selected(tester, 'second', 'markRead'), isTrue);

    await tester.tap(_choice('first', 'delete'));
    await tester.pumpAndSettle();
    await tester.tap(_choice('second', 'none'));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'first', 'delete'), isTrue);
    expect(_selected(tester, 'first', 'archive'), isFalse);
    expect(_selected(tester, 'second', 'none'), isTrue);
    expect(await tester.runAsync(() => getIt<SettingsRepository>().notificationActions()), (
      first: NotificationAction.delete,
      second: null,
    ));

    const account = Account(id: 'a1', address: 'ada@example.com', provider: ProviderKind.gmail, color: 0, position: 0);
    await tester.runAsync(() => getIt<NewMailNotifier>().notify(account, [msg('n')]));
    expect(h.notifications.shown.last.actions, [NotificationAction.delete]);
  });

  testWidgets('each choice reads with its place, and Tab then Space chooses it', (tester) async {
    final semantics = tester.ensureSemantics();
    await openPhoneDeviceSettings(tester);
    expect(tester.getSemantics(_choice('second', 'star')).label, 'Seconda Azione della notifica\nAggiungi Stella');

    Focus.of(tester.element(find.descendant(of: _choice('second', 'star'), matching: find.byType(Text))))
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_selected(tester, 'second', 'delete'), isTrue);
    semantics.dispose();
  });
}
