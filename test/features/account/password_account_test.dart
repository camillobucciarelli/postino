// «Collega iCloud» and «Altro IMAP» (#162): the form, autodiscovery or manual servers, each error, the reconnection.

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/password_provider.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

final _address = find.byKey(const ValueKey('password-form-address'));
final _password = find.byKey(const ValueKey('password-form-password'));
final _connect = find.byKey(const ValueKey('password-form-connect'));

const _fastmail = ServerSettings(
  imap: MailServer(host: 'imap.fastmail.com', port: 993, security: ServerSecurity.ssl),
  smtp: MailServer(host: 'smtp.fastmail.com', port: 465, security: ServerSecurity.ssl),
);

Future<Harness> _start(WidgetTester tester) async {
  final h = await Harness.create();
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  await tester.pumpAndSettle();
  return h;
}

Finder _in(Finder field) => find.descendant(of: field, matching: find.byType(TextField));

Future<void> _fill(WidgetTester tester, String address, String password) async {
  await tester.enterText(_in(_address), address);
  await tester.enterText(_in(_password), password);
}

Future<void> _open(WidgetTester tester, String choice) async {
  await tester.tap(find.text(choice));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_connect);
  await tester.pumpAndSettle();
  await tester.tap(_connect);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Collega iCloud: app-specific password, Apple link, then the Posta', (tester) async {
    final h = await _start(tester);
    await _open(tester, 'Collega iCloud');

    expect(find.text('Password per app'), findsOneWidget);
    await tester.tap(find.text('Come creare una password per app'));
    expect(h.links.opened.single.host, 'support.apple.com');
    // Each field is named for the screen reader; the password one is an obscured field.
    expect(tester.getSemantics(_in(_address)), isSemantics(label: 'Indirizzo email', isTextField: true));
    expect(
      tester.getSemantics(_in(_password)),
      isSemantics(label: 'Password per app', isTextField: true, isObscured: true),
    );

    await _fill(tester, 'ada@icloud.com', 'app-password-1');
    await _submit(tester);

    expect(h.connection.tested.single.$1, icloudServers);
    expect(find.text('Posta unificata'), findsOneWidget);
    expect((await getIt<MailStore>().accounts()).single.id, 'icloud:ada@icloud.com');
  });

  testWidgets('Altro IMAP with autodiscovery: Enter in the password field connects', (tester) async {
    final h = await _start(tester);
    h.discovery.servers['ada@fastmail.com'] = _fastmail;
    await _open(tester, 'Altro IMAP');

    await _fill(tester, 'ada@fastmail.com', 'app-password-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(h.connection.tested.single.$1, _fastmail);
    expect(find.text('Posta unificata'), findsOneWidget);
  });

  testWidgets('Altro IMAP without discovered servers opens the manual form, which connects', (tester) async {
    final h = await _start(tester);
    await _open(tester, 'Altro IMAP');
    await _fill(tester, 'ada@example.org', 'app-password-1');
    await _submit(tester);

    expect(find.textContaining('Non ho trovato i server'), findsOneWidget);
    expect(h.keychain.values, isEmpty);

    // Empty hosts are refused in place.
    await _submit(tester);
    expect(find.text("Scrivi l'host del server."), findsNWidgets(2));

    const imap = 'Server IMAP (posta in arrivo)';
    const smtp = 'Server SMTP (posta in uscita)';
    await tester.ensureVisible(find.byKey(const ValueKey('$imap-host')));
    await tester.enterText(_in(find.byKey(const ValueKey('$imap-host'))), 'mail.example.org');
    await tester.enterText(_in(find.byKey(const ValueKey('$smtp-host'))), 'mail.example.org');
    await tester.enterText(_in(find.byKey(const ValueKey('$smtp-port'))), '465');
    await tester.ensureVisible(find.text('SSL/TLS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSL/TLS').last);
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(
      h.connection.tested.single.$1,
      const ServerSettings(
        imap: MailServer(host: 'mail.example.org', port: 993, security: ServerSecurity.ssl),
        smtp: MailServer(host: 'mail.example.org', port: 465, security: ServerSecurity.ssl),
      ),
    );
    expect(find.text('Posta unificata'), findsOneWidget);
  });

  testWidgets('each error shows its message and saves nothing', (tester) async {
    final h = await _start(tester);
    h.discovery.servers['ada@fastmail.com'] = _fastmail;
    await _open(tester, 'Altro IMAP');

    Future<void> attempt(String address, String password, String message) async {
      await _fill(tester, address, password);
      await _submit(tester);
      expect(find.textContaining(message), findsOneWidget, reason: message);
    }

    await attempt('ada', 'x', 'Scrivi un indirizzo email completo.');
    await attempt('ada@fastmail.com', '', 'Scrivi la password.');
    await attempt('ada@gmail.com', 'x', 'usa «Collega Gmail»');
    await attempt('ada@fastmail.com', 'wrong', 'ha rifiutato indirizzo o password');
    h.connection.failure = const OfflineFailure();
    await attempt('ada@fastmail.com', 'app-password-1', 'Server non raggiungibile');

    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);

    // Esc closes the form: the onboarding is still there.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_address, findsNothing);
    expect(find.text('Altro IMAP'), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets('the manual configuration and the error open and close, «Connessione…» fades in'
        '${reduced ? ', all at once with reduced motion' : ''} (#283)', (tester) async {
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final h = await _start(tester);
      await _open(tester, 'Altro IMAP');
      double shown(Finder f) =>
          tester.getSize(find.ancestor(of: f, matching: find.byType(PostinoSizeFade)).first).height;
      bool between(Finder f, double full) => shown(f) > 0 && shown(f) < full;

      // The manual configuration: duration-thread-expand.
      await tester.tap(find.text('Impostazione manuale dei server'));
      await tester.pump();
      await tester.pump(PostinoMotion.threadExpand ~/ 2);
      final imap = find.text('Server IMAP (posta in arrivo)');
      await tester.pumpAndSettle();
      final manual = shown(imap);
      await tester.tap(find.text('Impostazione manuale dei server'));
      await tester.pump();
      await tester.pump(PostinoMotion.threadExpand ~/ 2);
      expect(reduced ? imap.evaluate().isEmpty : between(imap, manual), isTrue, reason: 'half way it is closing');
      await tester.pumpAndSettle();
      expect(imap, findsNothing);

      // «Connessione…», then the error.
      h.connection
        ..gate = Completer<void>()
        ..failure = const OfflineFailure();
      h.discovery.servers['ada@fastmail.com'] = _fastmail;
      await _fill(tester, 'ada@fastmail.com', 'app-password-1');
      await tester.ensureVisible(_connect);
      await tester.pumpAndSettle();
      await tester.tap(_connect);
      await tester.pump();
      await tester.pump();
      await tester.pump(PostinoMotion.state ~/ 2);
      final spinner = find.byType(PostinoSpinner);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: spinner, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, reduced ? 1 : inExclusiveRange(0, 1));
      h.connection.gate!.complete();
      final error = find.textContaining('Server non raggiungibile');
      for (var i = 0; i < 10 && error.evaluate().isEmpty; i++) {
        await tester.pump();
      }
      await tester.pump(PostinoMotion.snackbar ~/ 2);
      final reveal = find.ancestor(of: error, matching: find.byType(PostinoSizeFade)).first;
      final full =
          tester.getSize(find.ancestor(of: error, matching: find.byType(PostinoBanner))).height + PostinoSpacing.s4;
      expect(tester.getSize(reveal).height, reduced ? full : inExclusiveRange(0, full));
      await tester.pumpAndSettle();
      expect(tester.getSize(reveal).height, full);
      expect(h.keychain.values, isEmpty);
    });
  }

  testWidgets('Annulla while the connection is tested closes the form and saves nothing', (tester) async {
    final h = await _start(tester);
    h.connection.gate = Completer<void>();
    await _open(tester, 'Collega iCloud');
    await _fill(tester, 'ada@icloud.com', 'app-password-1');
    await tester.ensureVisible(_connect);
    await tester.tap(_connect);
    await tester.pump();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    h.connection.gate!.complete();
    await tester.pumpAndSettle();

    expect(_address, findsNothing);
    expect(find.text('Collega iCloud'), findsOneWidget);
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  testWidgets('a Da ricollegare password Account reconnects from its Banner with the address locked', (tester) async {
    final h = await _start(tester);
    await _open(tester, 'Collega iCloud');
    await _fill(tester, 'ada@icloud.com', 'app-password-1');
    await _submit(tester);
    await getIt<MailStore>().setStatus('icloud:ada@icloud.com', AccountStatus.daRicollegare);
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();

    const banner = ValueKey('da-ricollegare-icloud:ada@icloud.com');
    expect(
      find.descendant(of: find.byKey(banner), matching: find.textContaining('non accetta più la password')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: find.byKey(banner), matching: find.text('Accedi')));
    await tester.pumpAndSettle();

    expect(find.text("Ricollega l'Account"), findsOneWidget);
    expect(tester.widget<TextField>(_in(_address)).readOnly, isTrue);
    expect(tester.widget<TextField>(_in(_address)).controller?.text, 'ada@icloud.com');

    h.connection.password = 'app-password-2';
    await tester.enterText(_in(_password), 'app-password-2');
    await _submit(tester);

    expect(find.byKey(banner), findsNothing);
    expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
  });
}
