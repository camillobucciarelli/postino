// Impostazioni del dispositivo › Notifiche immediate (#214): Android only, off by default; on starts the fake service
// and asks for the battery exemption, off stops it, the choice stays in the Impostazioni del dispositivo. The fixed
// notification opens the Posta unificata.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/features/impostazioni/presentation/immediate_notifications_row.dart';
import 'package:postino/main.dart';

import 'device_settings_steps.dart';

final _row = find.byKey(const ValueKey('immediate-notifications'));
final _switch = find.descendant(of: _row, matching: find.byType(Switch));

bool _switchOn(WidgetTester tester) => tester.widget<Switch>(_switch).value;

const _body =
    'La posta nuova arriva in tempo reale, anche con Postino chiuso. In cambio resta una notifica fissa e Postino '
    "chiede di non essere limitato dall'ottimizzazione batteria: consuma più batteria. Spente, la posta nuova si "
    'controlla circa ogni 15 minuti.';

void main() {
  testWidgets('not on Android: no switch', (tester) async {
    final h = await openPhoneDeviceSettings(tester);
    expect(find.text('Impostazioni del dispositivo'), findsOneWidget);
    expect(_row, findsNothing);
    expect(h.immediate.calls, isEmpty);
  });

  testWidgets('on Android it is off by default, with its price', (tester) async {
    final h = await openPhoneDeviceSettings(tester, android: true);
    expect(_row, findsOneWidget);
    expect(_switchOn(tester), isFalse);
    expect(find.text(_body), findsOneWidget);
    expect(h.immediate.running, isFalse);
    expect(await getIt<SettingsRepository>().immediateNotifications(), isNull);
  });

  testWidgets('on: the service starts and the battery exemption is asked; off: it stops; the choice is kept', (
    tester,
  ) async {
    final h = await openPhoneDeviceSettings(tester, android: true);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(h.immediate.calls, [true]);
    expect(h.immediate.exemptionRequests, 1);
    expect(h.immediate.notice, (
      channel: 'Postino in ascolto',
      title: 'Postino in ascolto',
      text: 'La posta nuova arriva in tempo reale. Tocca per aprire la Posta unificata.',
    ));
    expect(await getIt<SettingsRepository>().immediateNotifications(), isTrue);

    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
    expect(h.immediate.calls, [true, false]);
    expect(h.immediate.running, isFalse);
    expect(await getIt<SettingsRepository>().immediateNotifications(), isFalse);
  });

  testWidgets('a refusal of the OS leaves it off, not remembered, and says so', (tester) async {
    final h = await openPhoneDeviceSettings(tester, android: true);
    h.immediate.failure = Exception('refused');
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
    expect(h.immediate.exemptionRequests, 0);
    expect(find.text('Il sistema non ha avviato le Notifiche immediate. Riprova.'), findsOneWidget);
    expect(await getIt<SettingsRepository>().immediateNotifications(), isNull);
  });

  testWidgets('one switch for the screen reader, with its title, price and state, toggled from the keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await openPhoneDeviceSettings(tester, android: true);
    expect(
      tester.getSemantics(_row),
      matchesSemantics(
        label: 'Notifiche immediate\n$_body',
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    var tabs = 0;
    while (FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ImmediateNotificationsRow>() ==
        null) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(++tabs, lessThan(10), reason: 'Tab reaches the switch');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(h.immediate.calls, [true]);
    expect(_switchOn(tester), isTrue);
    semantics.dispose();
  });

  testWidgets('the fixed notification tapped opens the Posta unificata', (tester) async {
    final h = await openPhoneDeviceSettings(tester, android: true);
    h.immediate.tap();
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni del dispositivo'), findsNothing);
    expect(find.text('Posta unificata'), findsWidgets);
  });
}
