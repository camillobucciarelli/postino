import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/accounts_repository.dart';
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
      expect(find.descendant(of: row, matching: find.text('Ciao')), findsOneWidget);
      // The first Account gets the first color of the palette.
      expect(accountBar(tester, row), PostinoColors.light.account(PostinoAccountColor.sky).color);
    },
  );

  testWidgets('without a Google client ID the onboarding says so', (tester) async {
    final h = await Harness.create();
    h.consent.failure = const ConfigurationFailure('GOOGLE_CLIENT_ID');

    await _start(tester);
    await tester.tap(find.text('Collega Gmail'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);
    expect(find.text('Collega Gmail'), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'the error of a connection opens over the choices${reduced ? ', at once with reduced motion' : ''} (#283)',
      (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final h = await Harness.create();
        h.consent.failure = const ConfigurationFailure('GOOGLE_CLIENT_ID');
        await _start(tester);
        await tester.tap(find.text('Collega Gmail'));
        final error = find.textContaining('GOOGLE_CLIENT_ID');
        for (var i = 0; i < 20 && error.evaluate().isEmpty; i++) {
          await tester.pump();
        }
        await tester.pump();
        await tester.pump(PostinoMotion.snackbar ~/ 2);
        final reveal = find.ancestor(of: error, matching: find.byType(PostinoSizeFade)).first;
        final full =
            tester.getSize(find.ancestor(of: error, matching: find.byType(PostinoBanner))).height + PostinoSpacing.s2;
        expect(tester.getSize(reveal).height, reduced ? full : inExclusiveRange(0, full));
        await tester.pumpAndSettle();
        expect(tester.getSize(reveal).height, full);
      },
    );
  }

  testWidgets('without the Gmail permission the onboarding asks to retry granting it', (tester) async {
    final h = await Harness.create();
    h.consent.failure = const MissingPermissionFailure();

    await _start(tester);
    await tester.tap(find.text('Collega Gmail'));
    await tester.pumpAndSettle();

    expect(find.textContaining('accesso a Gmail'), findsOneWidget);
    expect(find.text('Collega Gmail'), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'the onboarding fades through to the Posta when the first Account arrives (#283)${reduced ? ', at once with reduced motion' : ''}',
      (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final handle = tester.ensureSemantics();
        final h = await Harness.create();
        h.providerFor('gmail:ada@gmail.com').deliver(msg('m1', subject: 'Ciao'));
        await _start(tester);
        // The gate's fade, the outermost.
        double opacity() => tester
            .widget<FadeTransition>(
              find.descendant(of: find.byType(PostinoFadeThrough).first, matching: find.byType(FadeTransition)).first,
            )
            .opacity
            .value;
        expect(opacity(), 1, reason: 'what the start shows is just there');

        await tester.tap(find.text('Collega Gmail'));
        final seen = <double>[];
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(opacity());
          // While it fades out the onboarding answers no more.
          if (opacity() < 1 && find.text('Collega Gmail').evaluate().isNotEmpty) {
            expect(find.semantics.byLabel('Collega Gmail'), findsNothing);
          }
        }
        await tester.pumpAndSettle();
        expect(find.text('Posta unificata'), findsOneWidget);
        expect(opacity(), 1);
        if (reduced) {
          expect(seen, everyElement(1));
        } else {
          expect(seen.any((o) => o > 0 && o < 1), isTrue, reason: 'it fades, it does not pop');
        }
        handle.dispose();
      },
    );
  }

  testWidgets('the Posta fades through back to the onboarding when the last Account goes (#283)', (tester) async {
    final h = await Harness.create();
    await h.addAccount('a1');
    await _start(tester);
    expect(find.text('Collega Gmail'), findsNothing);
    double opacity() => tester
        .widget<FadeTransition>(
          find.descendant(of: find.byType(PostinoFadeThrough).first, matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;
    unawaited(getIt<AccountsRepository>().remove('a1'));
    final seen = <double>[];
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(pumpEventQueue);
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(opacity());
    }
    await tester.pumpAndSettle();
    expect(find.text('Collega Gmail'), findsOneWidget);
    expect(seen.any((o) => o > 0 && o < 1), isTrue, reason: 'it fades, it does not pop');
  });
}
