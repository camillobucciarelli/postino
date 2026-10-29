import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

Future<void> _start(WidgetTester tester) async {
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

const _viaggi = 'Label_12';

void main() {
  testWidgets('opening an Account shows only its inbox', (tester) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('x', subject: 'Da uno'));
    (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));

    await _start(tester);
    expect(find.text('Da uno'), findsOneWidget);
    expect(find.text('Da due'), findsOneWidget);

    await _tap(tester, 'account-a1');
    expect(find.text('Da uno'), findsOneWidget);
    expect(find.text('Da due'), findsNothing);
  });

  testWidgets('an Account shows only its own Etichette, and opens one', (
    tester,
  ) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1
      ..deliver(msg('x', subject: 'Inbox uno'))
      ..deliver(
        msg(
          'l',
          subject: 'In viaggio',
          labelIds: const [_viaggi],
          isStarred: true,
        ),
      );
    final a2 = await h.addAccount('a2');
    a2.labels
      ..clear()
      ..add(
        const Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta),
      );
    a2.deliver(msg('z', subject: 'Lavoro due', labelIds: const ['Label_7']));

    await _start(tester);
    await _tap(tester, 'account-a1');
    expect(find.byKey(const ValueKey('label-$_viaggi')), findsOneWidget);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(find.text('Lavoro'), findsNothing);
    expect(find.text('INBOX'), findsNothing);
    expect(find.text('In viaggio'), findsNothing, reason: 'not in the inbox');

    await _tap(tester, 'label-$_viaggi');
    expect(find.text('In viaggio'), findsOneWidget);
    expect(find.text('Inbox uno'), findsNothing);
    expect(find.text('Lavoro due'), findsNothing);
  });

  testWidgets('a message starred on the Provider shows the star everywhere', (
    tester,
  ) async {
    final h = await Harness.create();
    final a1 = await h.addAccount('a1');
    a1.deliver(msg('s', subject: 'Con stella', isStarred: true));
    a1.deliver(msg('n', subject: 'Senza stella'));

    Finder star(String id) => find.descendant(
      of: find.byKey(ValueKey('row-a1-$id')),
      matching: find.byIcon(Icons.star),
    );

    await _start(tester);
    expect(star('s'), findsOneWidget);
    expect(star('n'), findsNothing);

    await _tap(tester, 'account-a1');
    expect(star('s'), findsOneWidget);
    expect(star('n'), findsNothing);
  });
}
