// ModelDownloadBanner (#283): two stages that show the same banner (waiting for a yes, waiting for the Wi-Fi) change
// it in place, with no fade; a new stage fades over the old one.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/model_download_state.dart';
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

  Future<void> start(WidgetTester tester, ModelDownloadState state) async {
    model.emit(state);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: PostinoTheme.light(),
          home: const Scaffold(body: Column(children: [ModelDownloadBanner()])),
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
}
