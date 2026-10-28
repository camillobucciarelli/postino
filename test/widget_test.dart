import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

void main() {
  testWidgets('opens on the Posta route, translated in Italian', (
    tester,
  ) async {
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Postino'), findsOneWidget);
    expect(find.text('Posta in arrivo'), findsOneWidget);
  });

  testWidgets('opens on the Posta route, translated in English', (
    tester,
  ) async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Postino'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
  });
}
