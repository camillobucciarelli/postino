import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/accounts_service.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

Future<void> _start(WidgetTester tester) async {
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'without Accounts it shows the onboarding; after the consent the Posta unificata shows the Account in its color',
    (tester) async {
      final h = await Harness.create();
      // The Provider the new Account will sync from (id = provider:address).
      h.providerFor('gmail:ada@gmail.com').deliver(msg('m1', subject: 'Ciao'));

      await _start(tester);
      expect(find.text('Posta unificata'), findsNothing);

      await tester.tap(find.text('Collega Gmail'));
      await tester.pumpAndSettle();

      expect(find.text('Collega Gmail'), findsNothing);
      expect(find.text('Posta unificata'), findsOneWidget);
      final row = find.byKey(const ValueKey('row-gmail:ada@gmail.com-m1'));
      expect(
        find.descendant(of: row, matching: find.text('Ciao')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (w) =>
                w is ColoredBox &&
                w.key == const ValueKey('account-color') &&
                w.color.toARGB32() == accountColors.first,
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
