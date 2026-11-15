// L'etichetta con la versione installata (#297): versione e build dati, «sviluppo» senza define, selezionabile,
// letta come una frase, e presente nelle Impostazioni del dispositivo anche senza «Cerca aggiornamenti».

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/app_version.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/impostazioni/presentation/app_version_label.dart';
import 'package:postino/i18n/strings.g.dart';

import 'device_settings_steps.dart';

Future<void> _show(WidgetTester tester, AppVersion version, {AppLocale locale = AppLocale.it}) async {
  LocaleSettings.setLocaleSync(locale);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(body: AppVersionLabel(version: version)),
      ),
    ),
  );
}

void main() {
  testWidgets('a release shows its version and build number', (tester) async {
    await _show(tester, const AppVersion(version: '1.4.0', build: 1004000));
    expect(find.text('Postino 1.4.0 (build 1004000)'), findsOneWidget);
  });

  testWidgets('a development build says «sviluppo», not a made-up number', (tester) async {
    await _show(tester, const AppVersion());
    expect(find.text('Postino · sviluppo'), findsOneWidget);
    await _show(tester, const AppVersion(), locale: AppLocale.en);
    expect(find.text('Postino · development'), findsOneWidget);
  });

  testWidgets('it is selectable text and one sentence for the screen reader, not a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester, const AppVersion(version: '1.4.0', build: 1004000));
    expect(find.ancestor(of: find.byType(Text), matching: find.byType(SelectionArea)), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Postino 1.4.0 (build 1004000)')),
      matchesSemantics(label: 'Postino 1.4.0 (build 1004000)'),
    );
    handle.dispose();
  });

  testWidgets('the Impostazioni del dispositivo show it where «Cerca aggiornamenti» is not (a phone)', (tester) async {
    await openPhoneDeviceSettings(tester);
    expect(find.text('Cerca aggiornamenti'), findsNothing);
    expect(find.text('Postino · sviluppo'), findsOneWidget);
  });
}
