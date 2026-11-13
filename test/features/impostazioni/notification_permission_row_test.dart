// Impostazioni del dispositivo › «Notifiche» (#211): the permission as the fake OS says, and «Consenti».

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'device_settings_steps.dart';

final _allow = find.byKey(const ValueKey('notifications-allow'));

void main() {
  testWidgets('allowed: it says so, nothing to ask', (tester) async {
    await openPhoneDeviceSettings(tester);
    expect(find.text('Consentite'), findsOneWidget);
    expect(_allow, findsNothing);
  });

  testWidgets('not allowed: «Consenti», from the keyboard too, asks the OS, then says it is allowed', (tester) async {
    final h = await openPhoneDeviceSettings(tester, permissionNeeded: true);
    expect(find.text('Non consentite: la posta nuova arriva senza avviso.'), findsOneWidget);

    Focus.of(tester.element(find.descendant(of: _allow, matching: find.byType(Text)))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.notifications.requests, 1);
    expect(h.notifications.settingsOpened, 0);
    expect(find.text('Consentite'), findsOneWidget);
    expect(_allow, findsNothing);
  });

  testWidgets('the OS no longer asks: «Consenti» opens the system settings; back from them, the row reads again', (
    tester,
  ) async {
    final h = await openPhoneDeviceSettings(tester, permissionNeeded: true);
    h.notifications.grants = false;

    await tester.tap(_allow);
    await tester.pumpAndSettle();
    expect(h.notifications.settingsOpened, 1);
    expect(_allow, findsOneWidget);

    // Allowed in the system settings, then back to Postino.
    h.notifications.needed = false;
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Consentite'), findsOneWidget);
  });
}
