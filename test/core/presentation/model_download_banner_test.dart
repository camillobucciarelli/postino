// ModelDownloadBanner (#283): two stages that show the same banner (waiting for a yes, waiting for the Wi-Fi) change
// it in place, with no fade; a new stage fades over the old one.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/model_download_state.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/presentation/model_download_banner.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';

import '../../support/fake_model_download.dart';

void main() {
  late FakeModelDownload model;

  setUp(() {
    model = FakeModelDownload();
    GetIt.I.registerSingleton<ModelDownload>(model);
    LocaleSettings.setLocaleSync(AppLocale.it);
  });
  tearDown(() => GetIt.I.reset());

  Future<void> start(WidgetTester tester, ModelDownloadState state, {EdgeInsets padding = EdgeInsets.zero}) async {
    model.emit(state);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: PostinoTheme.light(),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [ModelDownloadBanner(padding: padding)],
            ),
          ),
        ),
      ),
    );
  }

  final banner = find.byKey(const ValueKey('model-banner'));

  testWidgets('waiting for a yes, then for the Wi-Fi: the same banner, changed in place', (tester) async {
    await start(tester, const ModelDownloadAwaitingConfirmation(300000000));
    model.emit(const ModelDownloadWaitingForWifi(300000000));
    await tester.pump();
    await tester.pump(PostinoMotion.snackbar ~/ 2);
    expect(banner, findsOneWidget, reason: 'no second copy fading');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a new stage fades over the old one', (tester) async {
    await start(tester, const ModelDownloadAwaitingConfirmation(300000000));
    model.emit(const ModelDownloadInProgress(1, 300000000));
    await tester.pump();
    await tester.pump(PostinoMotion.snackbar ~/ 2);
    expect(banner, findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(banner, findsOneWidget);
  });

  testWidgets('its padding (#312) only while there is a banner', (tester) async {
    const padding = EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s4, PostinoSpacing.s4, 0);
    await start(tester, const ModelDownloadAbsent(), padding: padding);
    expect(tester.getSize(find.byType(ModelDownloadBanner)).height, 0, reason: 'no gap without a banner');

    model.emit(const ModelDownloadFailed(OfflineFailure()));
    await tester.pumpAndSettle();
    final outer = tester.getRect(find.byType(ModelDownloadBanner));
    final inner = tester.getRect(find.byType(PostinoBanner));
    expect(
      (inner.left - outer.left, inner.top - outer.top, outer.right - inner.right),
      (PostinoSpacing.s4, PostinoSpacing.s4, PostinoSpacing.s4),
    );
  });
}
