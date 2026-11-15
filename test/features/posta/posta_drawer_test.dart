// Which item of the drawer is the open one, and each Account as a group (#311): its Posta in arrivo, Bozze, Inviata,
// Cestino and Etichette (the user's folders included, never a system one), in Posta unificata too, open or closed
// as last left on this device; an Etichetta opens with its Account.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/app/posta/posta_routes.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_drawer.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

const _folder = 'cartella:Lavoro/Progetti';

/// Two Accounts: a1 (IMAP) with a folder, a system folder stored by a creation and a label, a2 with a label.
Future<void> _setUp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1', provider: ProviderKind.imap);
  await h.addAccount('a2');
  final labels = getIt<PostinoDatabase>().labelsDao;
  await labels.upsert('a1', const Label(id: _folder, name: 'Lavoro/Progetti', kind: LabelKind.cartella));
  await labels.upsert('a1', const Label(id: sentLabelId, name: 'Sent', kind: LabelKind.cartella));
  await labels.upsert('a1', const Label(id: 'Label_1', name: 'Fatture', kind: LabelKind.etichetta));
  await labels.upsert('a2', const Label(id: 'Label_2', name: 'Bonifici', kind: LabelKind.etichetta));
  LocaleSettings.setLocaleSync(AppLocale.it);
}

Future<void> _pump(
  WidgetTester tester, {
  String? accountId,
  String? labelId,
  void Function(String, String)? onOpenLabel,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostaDrawer(
            key: UniqueKey(),
            accountId: accountId,
            labelId: labelId,
            onOpenUnified: () {},
            onOpenAccount: (_) {},
            onOpenLabel: onOpenLabel ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The keys of the active items, children included.
Set<String> _active(WidgetTester tester) => {
  for (final section in tester.widget<PostinoNavigationDrawer>(find.byType(PostinoNavigationDrawer)).sections)
    for (final item in section.items)
      for (final i in [item, ...?item.children])
        if (i.active) (i.key! as ValueKey<String>).value,
};

Finder _account(String id) => find.byKey(ValueKey('account-$id'));

void main() {
  testWidgets('Posta unificata: only its own item is open', (tester) async {
    await _setUp(tester);
    await _pump(tester);
    expect(_active(tester), {'drawer-posta-unificata'});
  });

  testWidgets('an Account\'s inbox: its Posta in arrivo only', (tester) async {
    await _setUp(tester);
    await _pump(tester, accountId: 'a1');
    expect(_active(tester), {'inbox-a1'});
  });

  testWidgets('the Bozze, Inviata or Cestino of an Account: its item only', (tester) async {
    await _setUp(tester);
    for (final id in [draftLabelId, sentLabelId, trashLabelId]) {
      await _pump(tester, accountId: 'a2', labelId: id);
      expect(_active(tester), {'label-a2-$id'});
    }
  });

  testWidgets('every Account, in Posta unificata too, lists its Cestino, folders and labels, never a system folder', (
    tester,
  ) async {
    await _setUp(tester);
    await _pump(tester);
    expect(find.text('a1@example.com'), findsOneWidget);
    expect(find.text('Cestino'), findsNWidgets(2));
    expect(find.text('Lavoro/Progetti'), findsOneWidget);
    expect(find.text('Fatture'), findsOneWidget);
    expect(find.text('Bonifici'), findsOneWidget);
    expect(find.text('Sent'), findsNothing);
    // Elsewhere (picker, Etichettatura automatica) the folders stay out, as before.
    final names = await tester.runAsync(() => getIt<InboxRepository>().watchLabels('a1').first);
    expect(names!.map((l) => l.name), ['Fatture']);
  });

  testWidgets('a folder opens with its Account, its id one segment of the path', (tester) async {
    await _setUp(tester);
    final opened = <(String, String)>[];
    await _pump(tester, onOpenLabel: (a, l) => opened.add((a, l)));
    await tester.tap(find.text('Lavoro/Progetti'));
    expect(opened, [('a1', _folder)]);
    expect(PostaRoute.parse(Uri.parse(labelPath('a1', _folder)), isLayout: false).labelId, _folder);
  });

  testWidgets('closed for one Account stays closed for it on this device, the other open', (tester) async {
    await _setUp(tester);
    await _pump(tester);
    await tester.tap(_account('a1'));
    await tester.pumpAndSettle();
    expect(find.text('Lavoro/Progetti'), findsNothing);
    expect(find.text('Bonifici'), findsOneWidget);
    expect(await tester.runAsync(() => getIt<SettingsRepository>().collapsedAccounts()), {'a1'});

    await _pump(tester, accountId: 'a2');
    expect(find.text('Lavoro/Progetti'), findsNothing);
    expect(find.text('Bonifici'), findsOneWidget);
  });

  testWidgets('two quick taps on an Account both count: open again, nothing stored closed', (tester) async {
    await _setUp(tester);
    await _pump(tester);
    await tester.tap(_account('a1'));
    await tester.pump();
    await tester.tap(_account('a1'));
    await tester.pumpAndSettle();
    expect(find.text('Lavoro/Progetti'), findsOneWidget);
    expect(await tester.runAsync(() => getIt<SettingsRepository>().collapsedAccounts()), isEmpty);
  });

  testWidgets('a stored value that is not a list leaves every Account open', (tester) async {
    await _setUp(tester);
    await tester.runAsync(() => getIt<PostinoDatabase>().deviceSettingsDao.write('drawer_collapsed_accounts', 'x'));
    await _pump(tester);
    expect(_account('a1'), findsOneWidget);
    expect(find.text('Lavoro/Progetti'), findsOneWidget);
  });

  testWidgets('the Account row reads «Account <address>» and says whether it is expanded', (tester) async {
    final semantics = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(tester);
    expect(
      tester.getSemantics(_account('a1')),
      matchesSemantics(
        label: 'Account a1@example.com',
        isButton: true,
        hasSelectedState: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
