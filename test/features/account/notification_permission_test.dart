// The notification permission (#39): asked after the first Account is connected, with what the notifications show.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _title = 'Notifiche della posta nuova';
const _body =
    'Postino ti avvisa quando arriva un messaggio, con mittente, oggetto e anteprima. Il sistema ti chiederà il permesso.';

Future<Harness> _start(WidgetTester tester, {bool withAccount = false, bool needed = true}) async {
  final h = await Harness.create();
  h.notifications.needed = needed;
  if (withAccount) {
    (await h.addAccount('a1')).deliver(msg('a'));
  } else {
    h.providerFor('gmail:ada@gmail.com').deliver(msg('m1'));
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _connect(WidgetTester tester) async {
  await tester.tap(find.text('Collega Gmail'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('after the first Account it explains the notifications, then Continua lets the OS ask', (tester) async {
    final h = await _start(tester);
    expect(find.text(_title), findsNothing);

    await _connect(tester);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_body), findsOneWidget);
    expect(h.notifications.requests, 0, reason: 'the explanation comes before the OS asks');

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(h.notifications.requests, 1);
    expect(find.text(_title), findsNothing);
    expect(find.text('Posta unificata'), findsOneWidget);
  });

  testWidgets('Non ora closes the explanation without asking', (tester) async {
    final h = await _start(tester);
    await _connect(tester);

    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();
    expect(h.notifications.requests, 0);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('a device with an Account never asked (before #39) gets the explanation at the start', (tester) async {
    await _start(tester, withAccount: true);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('once explained, a later start does not ask again', (tester) async {
    final h = await Harness.create();
    await getIt<SettingsRepository>().setNotificationsAsked();
    h.notifications.needed = true;
    (await h.addAccount('a1')).deliver(msg('a'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
    expect(h.notifications.requests, 0);
  });

  testWidgets('where the OS need not ask (Windows, Linux, already allowed) nothing shows', (tester) async {
    final h = await _start(tester, needed: false);
    await _connect(tester);
    expect(find.text(_title), findsNothing);
    expect(h.notifications.requests, 0);
  });
}
