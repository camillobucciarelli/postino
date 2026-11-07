// Impostazioni → «Account» (#162): the list of Accounts and «Aggiungi Account» with the onboarding's choice;
// «Rimuovi» on each Account (#174).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
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

/// «Rimuovi» on the Account a1, then «Rimuovi» in the dialog.
Future<void> _confirmRemoval(WidgetTester tester, [String id = 'a1']) async {
  await tester.tap(find.byKey(ValueKey('settings-remove-account-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rimuovi'));
  await _settle(tester);
}

/// Lets a removal end: it reads the Accounts left from a database stream, which answers outside the fake time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
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
    // The back arrow, «Rimuovi» of the Account, then «Aggiungi Account»: the Accounts listed are not stops.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
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

  testWidgets('«Rimuovi» is named after the Account; the dialog starts on «Annulla»; confirmed, it goes', (
    tester,
  ) async {
    final h = await _start(tester);
    await h.addAccount('a2');
    await tester.pumpAndSettle();
    // Its accessible name is the tooltip, read by VoiceOver.
    const name = "Rimuovi l'Account a1@example.com";
    expect(
      tester.getSemantics(find.byTooltip(name)),
      isSemantics(tooltip: name, isButton: true, isFocusable: true, hasTapAction: true),
    );

    // From the keyboard: back arrow, then «Rimuovi» of the first Account.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text("Rimuovere l'Account a1@example.com?"), findsOneWidget);
    expect(
      find.text('Le email scaricate su questo dispositivo vengono eliminate; sul server restano come sono.'),
      findsOneWidget,
    );
    // A Gmail Account: the revocation at Google is said too.
    expect(
      find.text(
        'Le modifiche non ancora inviate al server vanno perse.\n'
        'Postino revoca anche il suo accesso a Gmail su Google: gli altri dispositivi collegati con questo Account '
        'dovranno ricollegarlo.',
      ),
      findsOneWidget,
    );
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(of: find.text('Annulla'), matching: find.byElementPredicate((e) => identical(e, focused))),
      findsOneWidget,
      reason: 'the focus starts on «Annulla»',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text("Rimuovere l'Account a1@example.com?"), findsNothing);
    expect(find.byKey(const ValueKey('settings-account-a1')), findsOneWidget);

    await _confirmRemoval(tester);
    expect(find.byKey(const ValueKey('settings-account-a1')), findsNothing);
    expect(find.byKey(const ValueKey('settings-account-a2')), findsOneWidget);
  });

  testWidgets('removing the last Account goes back to the onboarding', (tester) async {
    await _start(tester);

    await _confirmRemoval(tester);

    expect(find.text('Tutte le tue caselle in un posto solo.'), findsOneWidget);
    expect(find.text('Collega Gmail'), findsOneWidget);
  });

  testWidgets('two removals at once: the one that leaves no Account goes back to the onboarding', (tester) async {
    final h = await _start(tester);
    await h.addAccount('a2');
    await tester.pumpAndSettle();
    // a1's queue is busy with a sync: its removal waits behind it while a2 is removed.
    final a1 = getIt<MailProvider>(instanceName: 'a1') as FakeMailProvider..hold = Completer<void>();
    unawaited(getIt<MailSync>().syncAll());
    await tester.pump();

    await _confirmRemoval(tester);
    await _confirmRemoval(tester, 'a2');
    a1.hold!.complete();
    await _settle(tester);

    expect(find.text('Tutte le tue caselle in un posto solo.'), findsOneWidget);
  });

  testWidgets('removing an IMAP Account says nothing about Google', (tester) async {
    final h = await _start(tester);
    await h.addAccount('imap1', provider: ProviderKind.imap);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-remove-account-imap1')));
    await tester.pumpAndSettle();

    expect(find.text('Le modifiche non ancora inviate al server vanno perse.'), findsOneWidget);
    expect(find.textContaining('revoca'), findsNothing);
  });
}
