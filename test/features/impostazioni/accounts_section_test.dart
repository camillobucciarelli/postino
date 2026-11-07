// Impostazioni → «Account» (#162): the list of Accounts and «Aggiungi Account» with the onboarding's choice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

final _add = find.byKey(const ValueKey('settings-add-account'));

Future<Harness> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  return h;
}

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> _connectIcloud(WidgetTester tester, String address) async {
  await tester.tap(_add);
  await tester.pumpAndSettle();
  expect(find.text('Collega Gmail'), findsOneWidget);
  expect(find.text('Altro IMAP'), findsOneWidget);
  await tester.tap(find.text('Collega iCloud'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('password-form-address'), address);
  await tester.enterText(_field('password-form-password'), 'app-password-1');
  await tester.tap(find.byKey(const ValueKey('password-form-connect')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('«Account» lists the Accounts; «Aggiungi Account» adds one that then shows in the list', (tester) async {
    await _start(tester);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-account-a1')), findsOneWidget);
    expect(
      tester.getSemantics(_add),
      matchesSemantics(
        label: 'Aggiungi Account',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await _connectIcloud(tester, 'ada@icloud.com');

    // Both dialogs closed, the Impostazioni stay, the new Account is listed.
    expect(find.text('Collega iCloud'), findsNothing);
    final row = find.byKey(const ValueKey('settings-account-icloud:ada@icloud.com'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('iCloud')), findsOneWidget);
  });

  testWidgets('adding an Account already there says so and keeps the form open', (tester) async {
    await _start(tester);
    await _connectIcloud(tester, 'ada@icloud.com');

    await _connectIcloud(tester, 'ada@icloud.com');

    expect(find.text('Questo Account è già collegato.'), findsOneWidget);
    expect(find.byKey(const ValueKey('password-form-connect')), findsOneWidget);
  });

  testWidgets('from the keyboard: Tab reaches «Aggiungi Account», Enter opens the choice, Esc closes it', (
    tester,
  ) async {
    await _start(tester);
    // The back arrow, then «Aggiungi Account»: the Accounts listed are not stops.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Altro IMAP'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Altro IMAP'), findsNothing);
  });

  testWidgets('the same address with two Providers is two Accounts, each with its Provider for VoiceOver', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    final store = getIt<MailStore>();
    for (final (i, p) in [ProviderKind.gmail, ProviderKind.imap].indexed) {
      h.providerFor('${p.name}:ada@acme.com');
      await store.addAccount(
        Account(id: '${p.name}:ada@acme.com', address: 'ada@acme.com', provider: p, color: i, position: i),
      );
    }
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
    await tester.pumpAndSettle();

    for (final (id, provider) in [('gmail:ada@acme.com', 'Gmail'), ('imap:ada@acme.com', 'IMAP')]) {
      expect(tester.getSemantics(find.byKey(ValueKey('settings-account-$id'))).label, 'ada@acme.com\n$provider');
    }
    // The sections of each Account read apart too.
    expect(find.text('ADA@ACME.COM · GMAIL'), findsOneWidget);
    expect(find.text('ADA@ACME.COM · IMAP'), findsOneWidget);
  });
}
