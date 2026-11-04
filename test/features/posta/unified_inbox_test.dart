import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('shows the Provider inbox newest first, with every row detail', (
    tester,
  ) async {
    final h = await Harness.create();
    final gmail = await h.addAccount('a1', color: 4); // rose
    gmail.deliver(
      msg(
        'old',
        date: DateTime.utc(2026, 3, 1, 12),
        from: 'old@example.com',
        subject: 'Vecchio',
        snippet: 'anteprima vecchia',
        isRead: true,
      ),
    );
    gmail.deliver(
      msg(
        'new',
        date: DateTime.utc(2026, 3, 2, 12),
        from: 'new@example.com',
        subject: 'Nuovo',
        snippet: 'anteprima nuova',
        isStarred: true,
      ),
    );

    await _start(tester);

    final newRow = find.byKey(const ValueKey('row-a1-new'));
    final oldRow = find.byKey(const ValueKey('row-a1-old'));
    expect(newRow, findsOneWidget);
    expect(
      tester.getTopLeft(newRow).dy < tester.getTopLeft(oldRow).dy,
      isTrue,
      reason: 'newest first',
    );
    for (final text in [
      'new@example.com',
      'Nuovo',
      'anteprima nuova',
      '2 mar',
    ]) {
      expect(
        find.descendant(of: newRow, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: newRow,
        matching: find.byKey(const ValueKey('unread')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: oldRow,
        matching: find.byKey(const ValueKey('unread')),
      ),
      findsNothing,
    );
    expect(find.descendant(of: newRow, matching: starIcon), findsOneWidget);
    expect(find.descendant(of: oldRow, matching: starIcon), findsNothing);
    // Account bar and badge: the Accounts mix here.
    expect(
      accountBar(tester, newRow),
      PostinoColors.light.account(PostinoAccountColor.rose).color,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: newRow,
              matching: find.byKey(const ValueKey('account-bar')),
            ),
          )
          .height,
      greaterThan(0),
      reason: 'the bar must be visible',
    );
    expect(
      find.descendant(of: newRow, matching: find.byType(PostinoAccountMark)),
      findsOneWidget,
    );
  });

  testWidgets(
    'merges the inboxes of two Accounts, each row in its Account color',
    (tester) async {
      final h = await Harness.create();
      (await h.addAccount('a1', color: 4)).deliver(
        msg('x', date: DateTime.utc(2026, 3, 1, 12), subject: 'Da uno'),
      );
      (await h.addAccount('a2', color: 5)).deliver(
        msg('x', date: DateTime.utc(2026, 3, 2, 12), subject: 'Da due'),
      );
      // Not in the inbox: must not show up.
      (await h.addAccount('a3'))
          .deliver(msg('y', labelIds: const ['SENT'], subject: 'Inviato'));

      await _start(tester);

      Color? bar(String row) => accountBar(tester, find.byKey(ValueKey(row)));
      const light = PostinoColors.light;
      expect(bar('row-a1-x'), light.account(PostinoAccountColor.rose).color);
      expect(bar('row-a2-x'), light.account(PostinoAccountColor.olive).color);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row-a2-x'))).dy <
            tester.getTopLeft(find.byKey(const ValueKey('row-a1-x'))).dy,
        isTrue,
      );
      expect(find.text('Inviato'), findsNothing);
    },
  );

  testWidgets('in dark mode the Account color follows the theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final h = await Harness.create();
    (await h.addAccount('a1', color: 4)).deliver(msg('x'));

    await _start(tester);

    const rose = PostinoAccountColor.rose;
    expect(
      accountBar(tester, find.byKey(const ValueKey('row-a1-x'))),
      allOf(
        PostinoColors.dark.account(rose).color,
        isNot(PostinoColors.light.account(rose).color),
      ),
    );
  });

  testWidgets('an empty inbox shows the EmptyState', (tester) async {
    await (await Harness.create()).addAccount('a1');
    await _start(tester);
    expect(find.byType(PostinoEmptyState), findsOneWidget);
    expect(find.text('Niente di nuovo'), findsOneWidget);
  });
}
