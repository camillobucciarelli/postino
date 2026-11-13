// «Collega Outlook» (#179): onboarding, «Aggiungi Account», each error, the keyboard, the banner Da ricollegare, and
// the Microsoft addresses of «Altro IMAP».

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = 'microsoft:ada@outlook.com';
const _banner = ValueKey('da-ricollegare-$_id');
final _outlook = find.widgetWithText(PostinoButton, 'Collega Outlook');

Future<void> _start(WidgetTester tester) async {
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  await tester.pumpAndSettle();
}

/// Whether the focus is on [f] or inside it.
bool _focusedIn(Finder f) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final target = f.evaluate().single;
  var found = identical(context, target);
  context.visitAncestorElements((a) => !(found = found || identical(a, target)));
  return found;
}

void main() {
  testWidgets('onboarding → «Collega Outlook»: the Account shows in Posta unificata in its color', (tester) async {
    final h = await Harness.create();
    h.providerFor(_id).deliver(msg('m1', subject: 'Ciao'));

    await _start(tester);
    await tester.tap(_outlook);
    await tester.pumpAndSettle();

    expect(find.text('Collega Outlook'), findsNothing);
    expect(find.text('Posta unificata'), findsOneWidget);
    final row = find.byKey(const ValueKey('row-$_id-m1'));
    expect(find.descendant(of: row, matching: find.text('Ciao')), findsOneWidget);
    expect(h.microsoft.runs, 1);
    expect(h.consent.runs, 0, reason: 'Google was not asked');
  });

  testWidgets('«Aggiungi Account» in Impostazioni offers it too, and the Account is then listed', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    await h.addAccount('a1');
    h.providerFor(_id);
    await _start(tester);
    Routefly.navigate(routePaths.posta.path).ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-add-account')));
    await tester.pumpAndSettle();
    await tester.tap(_outlook);
    await tester.pumpAndSettle();

    expect(_outlook, findsNothing, reason: 'the dialog closed');
    final row = find.byKey(const ValueKey('settings-account-$_id'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Microsoft')), findsOneWidget);
  });

  testWidgets('each error shows its message and saves nothing', (tester) async {
    final h = await Harness.create();
    await _start(tester);

    Future<void> attempt(Failure failure, String message) async {
      h.microsoft.failure = failure;
      await tester.tap(_outlook);
      await tester.pumpAndSettle();
      expect(find.textContaining(message), findsOneWidget, reason: message);
      expect(_outlook, findsOneWidget);
    }

    await attempt(const ConfigurationFailure('MICROSOFT_CLIENT_ID'), 'MICROSOFT_CLIENT_ID');
    await attempt(const WorkAccountFailure(), 'account Microsoft personali');
    await attempt(const MissingPermissionFailure(), 'leggere e inviare la posta');
    await attempt(const OfflineFailure(), 'Nessuna connessione');
    await attempt(const AlreadyConnectedFailure(), 'già collegato');
    await attempt(const UnexpectedFailure('x'), 'Qualcosa è andato storto');
    // Closing the browser is not an error.
    h.microsoft.failure = const CancelledFailure();
    await tester.tap(_outlook);
    await tester.pumpAndSettle();
    expect(find.text('Collegamento non riuscito'), findsNothing);

    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  testWidgets('«Collega Outlook» is a button between Gmail and iCloud, reached with Tab, activated with Enter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await Harness.create();
    h.providerFor(_id);
    await _start(tester);

    expect(
      tester.getSemantics(_outlook),
      isSemantics(label: 'Collega Outlook', isButton: true, isFocusable: true, hasTapAction: true),
    );
    const order = ['Collega Gmail', 'Collega Outlook', 'Collega iCloud', 'Altro IMAP'];
    for (final label in order) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedIn(find.widgetWithText(PostinoButton, label)), isTrue, reason: label);
      if (label == 'Collega Outlook') {
        // Space and Enter on it run the consent (the first one fails, so the screen stays).
        h.microsoft.failure = const OfflineFailure();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.textContaining('Nessuna connessione'), findsOneWidget);
        h.microsoft.failure = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(h.microsoft.runs, 1);
        break;
      }
    }
    semantics.dispose();
  });

  testWidgets('a Microsoft address in «Altro IMAP» points to «Collega Outlook», nothing saved', (tester) async {
    final h = await Harness.create();
    await _start(tester);
    await tester.tap(find.text('Altro IMAP'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('password-form-address')), matching: find.byType(TextField)),
      'ada@outlook.com',
    );
    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('password-form-password')), matching: find.byType(TextField)),
      'x',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('password-form-connect')));
    await tester.tap(find.byKey(const ValueKey('password-form-connect')));
    await tester.pumpAndSettle();

    expect(find.textContaining('usa «Collega Outlook»'), findsOneWidget);
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  group('Da ricollegare', () {
    late Harness h;
    late FakeMailProvider provider;

    Future<void> start(WidgetTester tester) async {
      h = await Harness.create();
      provider = h.providerFor(_id)..deliver(msg('old'));
      await getIt<AccountsRepository>().connectMicrosoft();
      await _start(tester);
      provider.breakAuth();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
    }

    testWidgets('the banner is a warning and opens the Microsoft consent with the address, not the password form', (
      tester,
    ) async {
      await start(tester);

      final banner = tester.widget<PostinoBanner>(find.byKey(_banner));
      expect(banner.tone, PostinoBannerTone.warning);
      expect(
        find.descendant(of: find.byKey(_banner), matching: find.textContaining('Microsoft non accetta')),
        findsOneWidget,
      );

      provider.restoreAuth();
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();

      expect(h.microsoft.lastLoginHint, 'ada@outlook.com');
      expect(h.consent.runs, 0, reason: 'Google is never asked for a Microsoft Account');
      expect(find.byKey(_banner), findsNothing);
      expect(find.byKey(const ValueKey('row-$_id-old')), findsOneWidget);
    });

    testWidgets('another identity says which one to pick, the banner stays', (tester) async {
      await start(tester);

      h.microsoft.address = 'bob@outlook.com';
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('per ricollegare ada@outlook.com'), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
    });
  });
}
