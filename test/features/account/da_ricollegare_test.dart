// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = 'gmail:ada@gmail.com';
const _banner = ValueKey('da-ricollegare-$_id');
const _old = ValueKey('row-$_id-old');
const _new = ValueKey('row-$_id-new');

void main() {
  late Harness h;
  late FakeMailProvider gmail;

  Future<void> start(WidgetTester tester) async {
    h = await Harness.create();
    gmail = h.providerFor(_id)..deliver(msg('old'));
    await getIt<AccountsRepository>().connectGmail();
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.byKey(_old), findsOneWidget);
  }

  Future<void> sync(WidgetTester tester) async {
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
  }

  testWidgets('an AuthFailure makes the Account Da ricollegare; its synced mail stays visible', (tester) async {
    await start(tester);

    gmail.breakAuth();
    await sync(tester);

    expect(find.byKey(_old), findsOneWidget);
    expect(tester.widget<PostinoBanner>(find.byKey(_banner)).tone, PostinoBannerTone.warning);
    expect(find.descendant(of: find.byKey(_banner), matching: find.textContaining('ada@gmail.com')), findsOneWidget);
    expect(find.descendant(of: find.byKey(_banner), matching: find.text('Accedi')), findsOneWidget);
  });

  testWidgets('reconnecting brings the Account back to attivo and the sync resumes', (tester) async {
    await start(tester);
    gmail.breakAuth();
    await sync(tester);

    // The Provider would accept a new consent; until then the Account does not sync.
    gmail
      ..restoreAuth()
      ..deliver(msg('new'));
    await sync(tester);
    expect(find.byKey(_new), findsNothing);

    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();

    expect(h.consent.lastLoginHint, 'ada@gmail.com');
    expect(find.byKey(_banner), findsNothing);
    expect(find.byKey(_old), findsOneWidget);
    expect(find.byKey(_new), findsOneWidget);
  });

  testWidgets('reconnecting with another Google account says which one to pick', (tester) async {
    await start(tester);
    gmail.breakAuth();
    await sync(tester);

    h.consent.address = 'bob@gmail.com';
    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();

    expect(find.textContaining('per ricollegare ada@gmail.com'), findsOneWidget);
    expect(find.byKey(_banner), findsOneWidget);
  });

  testWidgets('in the app the banner opens over the list and closes once reconnected (#283), out of reach meanwhile', (
    tester,
  ) async {
    await start(tester);
    final top = tester.getTopLeft(find.byKey(_old)).dy;
    gmail.breakAuth();
    await getIt<SyncEngine>().syncAll();
    await tester.pump();
    await tester.pump();
    await tester.pump(PostinoMotion.snackbar ~/ 2);
    final half = tester.getTopLeft(find.byKey(_old)).dy - top;
    final full = tester.getSize(find.byKey(_banner)).height;
    expect(half, inExclusiveRange(0, full), reason: 'the list is pushed down bit by bit');
    await tester.pumpAndSettle();
    final open = tester.getTopLeft(find.byKey(_old)).dy - top;
    expect(open, greaterThan(half));

    final handle = tester.ensureSemantics();
    gmail.restoreAuth();
    await tester.tap(find.text('Accedi'));
    for (var i = 0; i < 10 && tester.getTopLeft(find.byKey(_old)).dy - top == open; i++) {
      await tester.pump();
    }
    await tester.pump(PostinoMotion.snackbar ~/ 4);
    expect(find.byKey(_banner), findsOneWidget, reason: 'still drawn while it closes');
    expect(tester.getTopLeft(find.byKey(_old)).dy - top, inExclusiveRange(0, open));
    expect(find.semantics.byLabel('Accedi'), findsNothing, reason: 'a leaving banner is not read');
    await tester.pumpAndSettle();
    expect(find.byKey(_banner), findsNothing);
    expect(tester.getTopLeft(find.byKey(_old)).dy, top);
    handle.dispose();
  });
}
