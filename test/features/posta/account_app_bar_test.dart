// The title of an Account's list (#311): a folder of the user and the Cestino, opened from the drawer, are named.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_app_bars.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

Future<void> _pump(WidgetTester tester, String labelId) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          key: UniqueKey(),
          body: AccountAppBar(accountId: 'a1', labelId: labelId, onSearch: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a folder of the user and the Cestino give the list its title', (tester) async {
    final h = await Harness.create();
    await h.addAccount('a1', provider: ProviderKind.imap);
    await getIt<PostinoDatabase>().labelsDao.upsert(
      'a1',
      const Label(id: 'cartella:Lavoro/Progetti', name: 'Lavoro/Progetti', kind: LabelKind.cartella),
    );
    LocaleSettings.setLocaleSync(AppLocale.it);

    await _pump(tester, 'cartella:Lavoro/Progetti');
    expect(find.text('Lavoro/Progetti'), findsOneWidget);

    await _pump(tester, trashLabelId);
    expect(find.text('Cestino'), findsOneWidget);
  });
}
