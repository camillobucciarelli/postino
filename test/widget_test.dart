import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

void main() {
  testWidgets('shows the inbox title in Italian by default', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    expect(find.text('Posta in arrivo'), findsOneWidget);
  });
}
