import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

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
      // The first Account gets the first color of the palette.
      expect(
        accountBar(tester, row),
        PostinoColors.light.account(PostinoAccountColor.sky).color,
      );
    },
  );

  testWidgets('without a Google client ID the onboarding says so', (
    tester,
  ) async {
    final h = await Harness.create();
    h.consent.failure = const ConfigurationFailure('GOOGLE_CLIENT_ID');

    await _start(tester);
    await tester.tap(find.text('Collega Gmail'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);
    expect(find.text('Collega Gmail'), findsOneWidget);
  });

  testWidgets(
    'without the Gmail permission the onboarding asks to retry granting it',
    (tester) async {
      final h = await Harness.create();
      h.consent.failure = const MissingPermissionFailure();

      await _start(tester);
      await tester.tap(find.text('Collega Gmail'));
      await tester.pumpAndSettle();

      expect(find.textContaining('accesso a Gmail'), findsOneWidget);
      expect(find.text('Collega Gmail'), findsOneWidget);
    },
  );
}
