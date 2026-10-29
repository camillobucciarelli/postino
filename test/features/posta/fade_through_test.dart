import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_app_bars.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

Future<void> _start(WidgetTester tester) async {
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
}

Finder get _fade => find
    .descendant(
      of: find.byType(PostinoFadeThrough),
      matching: find.byType(FadeTransition),
    )
    .first;

void main() {
  testWidgets('switching view fades the new content in, then settles', (
    tester,
  ) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('x', subject: 'Da uno'));
    (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));
    await _start(tester);

    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('account-a1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    // Old content (both Accounts) still there, fading out.
    expect(find.text('Da due'), findsOneWidget);
    final out = tester.widget<FadeTransition>(_fade).opacity.value;
    expect(out, greaterThan(0));
    expect(out, lessThan(1));
    await tester.pump(const Duration(milliseconds: 105));
    final mid = tester.widget<FadeTransition>(_fade).opacity.value;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    expect(
      find.descendant(
        of: find.byType(PostinoFadeThrough),
        matching: find.byType(ScaleTransition),
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(_fade).opacity.value, 1);
    expect(find.text('Da uno'), findsOneWidget);
  });

  testWidgets('Account to Account never shows the Posta unificata', (
    tester,
  ) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('x', subject: 'Da uno'));
    (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));
    await _start(tester);
    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('account-a1')));
    await tester.pumpAndSettle();

    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('account-a2')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(UnifiedAppBar), findsNothing, reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    expect(find.text('Da due'), findsOneWidget);
  });

  testWidgets('an opaque surface sits under the fade, in light and dark', (
    tester,
  ) async {
    for (final theme in [PostinoTheme.light(), PostinoTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const PostinoFadeThrough(transitionKey: 1, child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(PostinoFadeThrough),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color.a, 1);
      expect(box.color, theme.extension<PostinoColors>()!.surface);
    }
  });

  testWidgets('outgoing page keeps its State while fading out', (tester) async {
    var inits = 0;
    Widget host(String k) => MaterialApp(
      theme: PostinoTheme.light(),
      home: PostinoFadeThrough(
        transitionKey: k,
        child: _Probe(key: ValueKey('probe-$k'), onInit: () => inits++),
      ),
    );

    await tester.pumpWidget(host('a'));
    expect(inits, 1);
    final state = tester.state(find.byKey(const ValueKey('probe-a')));

    await tester.pumpWidget(host('b'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(inits, 1);
    expect(tester.state(find.byKey(const ValueKey('probe-a'))), same(state));

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('probe-a')), findsNothing);
    expect(inits, 2);
  });
}

class _Probe extends StatefulWidget {
  const _Probe({super.key, required this.onInit});
  final VoidCallback onInit;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
