// Which item of the drawer is the open one: Account, Bozze or Inviati of the open Account only.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_drawer.dart';
import 'package:postino/i18n/strings.g.dart';

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
}
