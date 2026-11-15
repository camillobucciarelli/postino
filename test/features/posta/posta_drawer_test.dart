// Which item of the drawer is the open one: Account, Bozze or Inviati of the open Account only; the Etichette section
// of the open Account (#311): with the user's folders, hidden in Posta unificata, open or closed as last left here.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_drawer.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

Future<Set<String>> _active(WidgetTester tester, {String? accountId, String? labelId}) async {
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1');
  await h.addAccount('a2');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostaDrawer(
            accountId: accountId,
            labelId: labelId,
            onOpenUnified: () {},
            onOpenAccount: (_) {},
            onOpenLabel: (_) {},
            onOpenDrafts: (_) {},
            onOpenSent: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return {
    for (final section in tester.widget<PostinoNavigationDrawer>(find.byType(PostinoNavigationDrawer)).sections)
      for (final item in section.items)
        if (item.active) (item.key! as ValueKey<String>).value,
  };
}

void main() {
  testWidgets('Posta unificata: only its own item is open', (tester) async {
    expect(await _active(tester), {'drawer-posta-unificata'});
  });

  testWidgets('an Account without Etichetta: its inbox item only, not its Bozze nor Inviati', (tester) async {
    expect(await _active(tester, accountId: 'a1'), {'account-a1'});
  });

  testWidgets('the Bozze of an Account: its item only, not the other Account\'s Bozze', (tester) async {
    expect(await _active(tester, accountId: 'a2', labelId: draftLabelId), {'drafts-a2'});
  });

  testWidgets('the Inviati of an Account: its item only', (tester) async {
    expect(await _active(tester, accountId: 'a1', labelId: sentLabelId), {'sent-a1'});
  });

  testWidgets('an IMAP Account lists its folders and its labels under its own header', (tester) async {
    await _withLabels(tester);
    await _pumpDrawer(tester, accountId: 'a1');
    expect(find.textContaining('ETICHETTE DI '), findsOneWidget);
    expect(find.text('Lavoro/Progetti'), findsOneWidget);
    expect(find.text('Fatture'), findsOneWidget);
  });

  testWidgets('Posta unificata: no Etichette section', (tester) async {
    await _withLabels(tester);
    await _pumpDrawer(tester);
    expect(_header, findsNothing);
    expect(find.text('Lavoro/Progetti'), findsNothing);
  });

  testWidgets('closed for one Account stays closed for it, on this device, and open for the other', (tester) async {
    await _withLabels(tester);
    await _pumpDrawer(tester, accountId: 'a1');
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(find.text('Lavoro/Progetti'), findsNothing);
    expect(await tester.runAsync(() => getIt<SettingsRepository>().watchLabelsExpanded('a1').first), isFalse);

    await _pumpDrawer(tester, accountId: 'a2');
    expect(find.text('Bonifici'), findsOneWidget);

    await _pumpDrawer(tester, accountId: 'a1');
    expect(_header, findsOneWidget);
    expect(find.text('Lavoro/Progetti'), findsNothing);
  });
}

/// Two Accounts: a1 (IMAP) with a folder and a label, a2 with a label.
Future<void> _withLabels(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1', provider: ProviderKind.imap);
  await h.addAccount('a2');
  final labels = getIt<PostinoDatabase>().labelsDao;
  await labels.upsert(
    'a1',
    const Label(id: 'cartella:Lavoro/Progetti', name: 'Lavoro/Progetti', kind: LabelKind.cartella),
  );
  await labels.upsert('a1', const Label(id: 'Label_1', name: 'Fatture', kind: LabelKind.etichetta));
  await labels.upsert('a2', const Label(id: 'Label_2', name: 'Bonifici', kind: LabelKind.etichetta));
  LocaleSettings.setLocaleSync(AppLocale.it);
}

Future<void> _pumpDrawer(WidgetTester tester, {String? accountId}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostaDrawer(
            key: UniqueKey(),
            accountId: accountId,
            onOpenUnified: () {},
            onOpenAccount: (_) {},
            onOpenLabel: (_) {},
            onOpenDrafts: (_) {},
            onOpenSent: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _header => find.byKey(const ValueKey('drawer-section-toggle'));
