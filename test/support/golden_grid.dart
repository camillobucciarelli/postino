// The goldens of the design system: one image per component, light and dark side by side, text at 100% over 200%.
// ponytail: goldens are recorded and compared only on macOS (developers and the self-hosted Apple runner):
// Linux CI rasterises text and anti-aliasing differently (1-2% of pixels); the tap target guidelines still run everywhere.
// The text contrast guideline samples the rendered pixels too (the most frequent light and dark colour around
// each text): on Linux a small caption has no solid ink pixel winning over its anti-aliasing, so it runs on macOS only.
import 'dart:io';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _golden = ValueKey('golden');

/// Light and dark side by side, text at 100% over 200%.
Widget goldenGrid(Widget Function() build) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: PostinoTheme.light(),
  home: Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _golden,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final theme in [PostinoTheme.light(), PostinoTheme.dark()])
            Theme(
              data: theme,
              child: Builder(
                builder: (context) => Container(
                  width: 360,
                  color: context.pc.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final scale in [1.0, 2.0])
                        MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Padding(padding: const EdgeInsets.all(16), child: build()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);

/// One test per component of [components]: its golden `goldens/<name>.png` next to the calling test file,
/// the contrast and tap target guidelines. The names in [desktop] render as on macOS; with [settle] the test
/// pumps a few more frames, for a component that opens a route on its first frame.
void testComponentGoldens(
  Map<String, Widget Function()> components, {
  Set<String> desktop = const {},
  bool settle = false,
}) {
  for (final MapEntry(key: name, value: build) in components.entries) {
    testWidgets('$name matches its golden and the guidelines', (tester) async {
      tester.view
        ..physicalSize = const Size(720, 3200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      if (desktop.contains(name)) {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      }
      try {
        await tester.pumpWidget(goldenGrid(build));
        if (settle) {
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 400));
          }
        }
        if (Platform.isMacOS) {
          await expectLater(find.byKey(_golden), matchesGoldenFile('goldens/$name.png'));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      semantics.dispose();
    });
  }
}
