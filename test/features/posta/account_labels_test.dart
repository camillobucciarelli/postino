import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

Future<void> _start(WidgetTester tester) async {
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics: start each test from the Posta unificata.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// Opens [key] from the NavigationDrawer.
Future<void> _tap(WidgetTester tester, String key) async {
  await openDrawer(tester);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

const _viaggi = 'Label_12';

void main() {
  testWidgets('opening an Account from the drawer shows only its inbox', (tester) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('x', subject: 'Da uno'));
    (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));

    await _start(tester);
    expect(find.text('Da uno'), findsOneWidget);
    expect(find.text('Da due'), findsOneWidget);

    await _tap(tester, 'inbox-a1');
    expect(find.text('Da uno'), findsOneWidget);
    expect(find.text('Da due'), findsNothing);
    // No bar nor badge on the rows: the AppBar says where you are, with the Account's mark.
    final row = find.byKey(const ValueKey('row-a1-x'));
    expect(accountBar(tester, row), isNull);
    expect(find.descendant(of: row, matching: find.byType(PostinoAccountMark)), findsNothing);
    expect(find.descendant(of: find.byType(PostinoAppBar), matching: find.byType(PostinoAccountMark)), findsOneWidget);
    expect(find.descendant(of: find.byType(PostinoAppBar), matching: find.text('a1@example.com')), findsOneWidget);

    await _tap(tester, 'drawer-posta-unificata');
    expect(find.text('Da due'), findsOneWidget);
  });

  testWidgets('an Account shows only its own Etichette, and opens one', (tester) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1
      ..deliver(msg('x', subject: 'Inbox uno'))
      ..deliver(msg('l', subject: 'In viaggio', labelIds: const [_viaggi], isStarred: true));
    final a2 = await h.addAccount('a2');
    a2.labels
      ..clear()
      ..add(const Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta));
    a2.deliver(msg('z', subject: 'Lavoro due', labelIds: const ['Label_7']));

    await _start(tester);
    await _tap(tester, 'inbox-a1');
    await openDrawer(tester);
    // Each Account's group holds only its own Etichette.
    expect(find.byKey(const ValueKey('label-a1-$_viaggi')), findsOneWidget);
    expect(find.byKey(const ValueKey('label-a2-$_viaggi')), findsNothing);
    expect(find.byKey(const ValueKey('label-a2-Label_7')), findsOneWidget);
    expect(find.byKey(const ValueKey('label-a1-Label_7')), findsNothing);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(find.text('Lavoro'), findsOneWidget);
    expect(find.text('INBOX'), findsNothing);
    expect(find.text('In viaggio'), findsNothing, reason: 'not in the inbox');
    await tester.tap(find.byKey(const ValueKey('label-a1-$_viaggi')));
    await tester.pumpAndSettle();
    expect(find.text('In viaggio'), findsOneWidget);
    expect(find.text('Inbox uno'), findsNothing);
    expect(find.text('Lavoro due'), findsNothing);
    // Titled by the Etichetta's name, not its id.
    expect(find.descendant(of: find.byType(PostinoAppBar), matching: find.text('Viaggi')), findsOneWidget);
  });

  testWidgets('from an Account, the drawer opens another Account', (tester) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('x', subject: 'Da uno'));
    (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));

    await _start(tester);
    await _tap(tester, 'inbox-a1');
    expect(find.text('Da uno'), findsOneWidget);
    await _tap(tester, 'inbox-a2');
    expect(find.text('Da due'), findsOneWidget);
    expect(find.text('Da uno'), findsNothing);
    expect(find.descendant(of: find.byType(PostinoAppBar), matching: find.text('a2@example.com')), findsOneWidget);
  });

  testWidgets('from an Etichetta, the drawer opens another Etichetta', (tester) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1.labels.add(const Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta));
    a1
      ..deliver(msg('l', subject: 'In viaggio', labelIds: const [_viaggi]))
      ..deliver(msg('w', subject: 'Al lavoro', labelIds: const ['Label_7']));

    await _start(tester);
    await _tap(tester, 'inbox-a1');
    await _tap(tester, 'label-a1-$_viaggi');
    expect(find.text('In viaggio'), findsOneWidget);
    await _tap(tester, 'label-a1-Label_7');
    expect(find.text('Al lavoro'), findsOneWidget);
    expect(find.text('In viaggio'), findsNothing);
  });

  testWidgets('a message starred on the Provider shows the star everywhere', (tester) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1
      ..deliver(msg('s', subject: 'Con stella', isStarred: true))
      ..deliver(msg('n', subject: 'Senza stella'));

    Finder star(String id) => find.descendant(of: find.byKey(ValueKey('row-a1-$id')), matching: starIcon);

    await _start(tester);
    expect(star('s'), findsOneWidget);
    expect(star('n'), findsNothing);

    await _tap(tester, 'inbox-a1');
    expect(star('s'), findsOneWidget);
    expect(star('n'), findsNothing);
  });

  testWidgets('an Account Da ricollegare is announced in its own view', (tester) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1.deliver(msg('x'));

    await _start(tester);
    await _tap(tester, 'inbox-a1');
    a1.breakAuth();
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('da-ricollegare-a1')), findsOneWidget);
  });
}
