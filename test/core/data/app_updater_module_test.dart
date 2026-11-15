// The updater of each platform (#122, #287): Sparkle on macOS, the site on Android and iOS in a release build,
// nothing elsewhere, nor in the Mac App Store variant (#325).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/app_updater_module.dart';
import 'package:postino/core/data/desktop/channel_app_updater.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/site_app_updater.dart';

import '../../support/fake_platform.dart';

void main() {
  late PostinoDatabase db;
  setUp(() => db = PostinoDatabase.inMemory());
  tearDown(() => db.close());

  final client = MockClient((_) async => http.Response('', 404));
  final clock = FakeClock(DateTime.utc(2026, 11, 14));

  test('macOS keeps Sparkle', () {
    expect(appUpdaterFor(TargetPlatform.macOS, 1003000, client, db, clock), isA<ChannelAppUpdater>());
  });

  // `flutter build --flavor store` gives `store`; the Xcode build of the scheme gives its name, `Store`.
  for (final flavor in ['store', 'Store']) {
    test('the Mac App Store variant ($flavor) looks for nothing: the Store updates it (#325)', () {
      final u = appUpdaterFor(TargetPlatform.macOS, 1003000, client, db, clock, flavor: flavor);
      expect(u.supported, isFalse);
      expect(u.available, isNull);
    });
  }

  test('another flavor keeps Sparkle on macOS', () {
    expect(appUpdaterFor(TargetPlatform.macOS, 1003000, client, db, clock, flavor: 'dev'), isA<ChannelAppUpdater>());
  });

  for (final (platform, path) in [(TargetPlatform.android, 'android'), (TargetPlatform.iOS, 'ios')]) {
    test('${platform.name} reads its own version file on the site', () {
      final u = appUpdaterFor(platform, 1003000, client, db, clock);
      expect(u.supported, isTrue);
      expect((u as SiteAppUpdater).feed, Uri.parse('https://postino.camillobucciarelli.dev/$path/latest/version.json'));
      expect(u.installed, 1003000);
      expect(u.fallback, Uri.parse('https://postino.camillobucciarelli.dev/guida/index.html'));
    });

    test('${platform.name}: a development build (no build number) looks for nothing', () {
      expect(appUpdaterFor(platform, 0, client, db, clock).supported, isFalse);
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia, null]) {
    test('${platform?.name ?? 'web'} looks for nothing', () async {
      final u = appUpdaterFor(platform, 1003000, client, db, clock);
      expect(u.supported, isFalse);
      expect(u.available, isNull);
    });
  }
}
