// Two Accounts with the same address and different Providers (ADR 0016, #191): the drawer, the «Da» of the composer
// and the Etichette automatiche show and read out «indirizzo · Provider»; an address of its own reads as before.
import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

const _gmail = 'gmail:ada@acme.com';
const _imap = 'imap:ada@acme.com';
const _bob = 'gmail:bob@acme.com';

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final store = getIt<MailStore>();
  for (final (i, (id, address, provider)) in [
    (_gmail, 'ada@acme.com', ProviderKind.gmail),
    (_imap, 'ada@acme.com', ProviderKind.imap),
    (_bob, 'bob@acme.com', ProviderKind.gmail),
  ].indexed) {
    h.providerFor(id);
    await store.addAccount(Account(id: id, address: address, provider: provider, color: i, position: i));
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// flutter_quill reads the platform once: macOS, as the app in QA; semantics on, for the labels.
void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  _onMac('the drawer reads the Provider of a shared address, not of an address of its own', (tester) async {
    await _start(tester);
    expect(tester.getSemantics(find.byKey(const ValueKey('account-$_gmail'))).label, 'ada@acme.com · Gmail');
    expect(tester.getSemantics(find.byKey(const ValueKey('account-$_imap'))).label, 'ada@acme.com · IMAP');
    expect(tester.getSemantics(find.byKey(const ValueKey('account-$_bob'))).label, 'bob@acme.com');
  });

  _onMac('«Da» in the composer and its menu read the Provider of a shared address', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Scrivi'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Da: ada@acme.com · Gmail'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Da: ada@acme.com · Gmail'));
    await tester.pumpAndSettle();
    // The menu's entries, after the drawer's.
    final imap = find.text('ada@acme.com · IMAP').last;
    expect(find.text('ada@acme.com · IMAP'), findsNWidgets(2));
    expect(find.text('bob@acme.com'), findsNWidgets(2));
    await tester.tap(imap);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Da: ada@acme.com · IMAP'), findsOneWidget);
  });

  _onMac('the Etichette automatiche say which of the two Accounts they are of', (tester) async {
    await _start(tester);
    await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-auto-labels-$_imap')));
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni · ada@acme.com · IMAP'), findsOneWidget);
  });
}
