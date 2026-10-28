import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('shows the Provider inbox newest first, with every row detail', (
    tester,
  ) async {
    final h = await Harness.create();
    final gmail = h.addAccount('a1', color: 0xFFE91E63);
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
      '2026-03-02',
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
    expect(
      find.descendant(of: newRow, matching: find.byIcon(Icons.star)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: oldRow, matching: find.byIcon(Icons.star)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: newRow,
        matching: find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.key == const ValueKey('account-color') &&
              w.color == const Color(0xFFE91E63),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'merges the inboxes of two Accounts, each row in its Account color',
    (tester) async {
      final h = await Harness.create();
      h
          .addAccount('a1', color: 0xFFE91E63)
          .deliver(
            msg('x', date: DateTime.utc(2026, 3, 1, 12), subject: 'Da uno'),
          );
      h
          .addAccount('a2', color: 0xFF4CAF50)
          .deliver(
            msg('x', date: DateTime.utc(2026, 3, 2, 12), subject: 'Da due'),
          );
      // Not in the inbox: must not show up.
      h
          .addAccount('a3')
          .deliver(msg('y', labelIds: const ['SENT'], subject: 'Inviato'));

      await _start(tester);

      Finder colorOf(String row, int argb) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Color(argb),
        ),
      );
      expect(colorOf('row-a1-x', 0xFFE91E63), findsOneWidget);
      expect(colorOf('row-a2-x', 0xFF4CAF50), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row-a2-x'))).dy <
            tester.getTopLeft(find.byKey(const ValueKey('row-a1-x'))).dy,
        isTrue,
      );
      expect(find.text('Inviato'), findsNothing);
    },
  );
}
