import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import 'support/harness.dart';

void main() {
  testWidgets('opens on the Posta route, translated in Italian', (tester) async {
    await (await Harness.create()).addAccount('a1');
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Posta unificata'), findsOneWidget);
    expect(find.text('1 account'), findsOneWidget);
  });

  testWidgets('opens on the Posta route, translated in English', (tester) async {
    await (await Harness.create()).addAccount('a1');
    LocaleSettings.setLocaleSync(AppLocale.en);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('All inboxes'), findsOneWidget);
    expect(find.text('1 account'), findsOneWidget);
  });
}
