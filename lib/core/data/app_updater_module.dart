import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/app_updater.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'desktop/channel_app_updater.dart';
import 'postino_database.dart';
import 'site_app_updater.dart';

/// The site the release publishes to (release.yml).
const _site = 'https://postino.camillobucciarelli.dev';

/// The updater of this platform: Sparkle on macOS (#122), the site's version file on Android and iOS (#287) in a
/// release build; Windows and Linux are left for later. The Mac App Store variant (`--flavor store`, #325) has none:
/// the Store updates it.
@module
abstract class AppUpdaterModule() {
  @LazySingleton(env: [Environment.prod])
  AppUpdater appUpdater(http.Client client, PostinoDatabase db, Clock clock) => appUpdaterFor(
    kIsWeb ? null : defaultTargetPlatform,
    // This build's number, set by the release (build_number.sh); 0 in a development build, which checks nothing.
    const int.fromEnvironment('POSTINO_BUILD'),
    client,
    db,
    clock,
    // The analyzer sees appFlavor without --flavor (null), the redundant default.
    // ignore: avoid_redundant_argument_values
    flavor: appFlavor,
  );
}

/// The updater of [platform] (null on the web) for the build numbered [build]. The Mac App Store [flavor] has none on
/// macOS: `--flavor store`, which an Xcode build passes as the scheme's name, `Store`.
AppUpdater appUpdaterFor(
  TargetPlatform? platform,
  int build,
  http.Client client,
  PostinoDatabase db,
  Clock clock, {
  String? flavor,
}) => switch (platform) {
  TargetPlatform.macOS when flavor?.toLowerCase() != 'store' => const ChannelAppUpdater(),
  TargetPlatform.android || TargetPlatform.iOS when build > 0 => SiteAppUpdater(
    client,
    db.deviceSettingsDao,
    clock,
    feed: Uri.parse('$_site/${platform == TargetPlatform.iOS ? 'ios' : 'android'}/latest/version.json'),
    installed: build,
    launch: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
    fallback: Uri.parse('$_site/guida/index.html'),
    storeOnly: platform == TargetPlatform.iOS,
  ),
  _ => const _Unsupported(),
};

class const _Unsupported() implements AppUpdater {
  @override
  bool get supported => false;

  @override
  AppUpdate? get available => null;

  @override
  Stream<AppUpdate?> get changes => const Stream.empty();

  @override
  Future<void> checkDaily() async {}

  @override
  Future<Result<UpdateCheck>> checkForUpdates() async => const Ok(UpdateCheck.upToDate);

  @override
  Future<void> dismiss() async {}

  @override
  Future<void> download() async {}
}
