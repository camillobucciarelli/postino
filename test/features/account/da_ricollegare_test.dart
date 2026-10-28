import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _banner = ValueKey('da-ricollegare-a1');
const _old = ValueKey('row-a1-old');

void main() {
  late Harness h;
  late FakeMailProvider gmail;

  Future<void> start(WidgetTester tester) async {
    h = await Harness.create();
    gmail = (await h.addAccount('a1'))..deliver(msg('old'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.byKey(_old), findsOneWidget);
  }

  Future<void> sync(WidgetTester tester) async {
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an AuthFailure makes the Account Da ricollegare; its synced mail stays visible',
    (tester) async {
      await start(tester);

      gmail.breakAuth();
      await sync(tester);

      expect(find.byKey(_old), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_banner),
          matching: find.textContaining('a1@example.com'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_banner),
          matching: find.text('Ricollega'),
        ),
        findsOneWidget,
      );
    },
  );
}
