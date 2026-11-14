import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/app_updater.dart';
import '../domain/platform_services.dart';
import 'daos/device_settings_dao.dart';

/// Android and iOS (#287): the release publishes `<platform>/latest/version.json` on the site, `{"version": "X.Y.Z",
/// "build": N, "url": "..."}`; a build above the [installed] one is [available] until dismissed. The request carries
/// nothing of the user: a fixed HTTPS URL, no redirect followed (the same principle as `httpsOnly`), a short timeout.
/// Any failure leaves things as they are and is never logged: no Banner, no error.
class SiteAppUpdater(
  final http.Client _http,
  final DeviceSettingsDao _settings,
  final Clock _clock, {

  /// The version file of this platform.
  required final Uri feed,

  /// This build's number (`--dart-define=POSTINO_BUILD`, the release's build_number.sh).
  required final int installed,

  /// Opens a URL outside Postino; false when nothing can (TestFlight not installed).
  required final Future<bool> Function(Uri url) launch,

  /// Where [download] goes when the version's URL does not open: the invitees' guide.
  required final Uri fallback,
}) implements AppUpdater {
  static const _checkedKey = 'update_checked';
  static const _foundKey = 'update_found';
  static const _dismissedKey = 'update_dismissed';
  static const _day = Duration(days: 1);
  static const _timeout = Duration(seconds: 10);

  final _changes = StreamController<AppUpdate?>.broadcast();
  AppUpdate? _available;

  /// The daily check in progress: start and resume at once read the site once.
  Future<void>? _daily;

  @override
  bool get supported => true;

  @override
  AppUpdate? get available => _available;

  @override
  Stream<AppUpdate?> get changes => _changes.stream;

  @override
  Future<void> checkDaily() => _daily ??= _checkDaily().whenComplete(() => _daily = null);

  Future<void> _checkDaily() async {
    try {
      final last = DateTime.tryParse(await _settings.read(_checkedKey) ?? '');
      final now = _clock.now();
      // A clock moved back counts as a day gone.
      final due = last == null || now.difference(last) >= _day || now.isBefore(last);
      // Within the day, the last answer: a restart shows the same Banner without asking the site again.
      final update = due ? await _fetch() : _newer(await _settings.read(_foundKey));
      _show(update, dismissed: await _settings.read(_dismissedKey));
    } on Object catch (e) {
      // The type only, and never in the error log: nothing the user needs to know.
      debugPrint('[aggiornamenti] ${e.runtimeType}');
    }
  }

  @override
  Future<UpdateCheck> checkForUpdates() async {
    try {
      final update = await _fetch();
      // Asked for: a version dismissed shows again.
      await _settings.write(_dismissedKey, null);
      _show(update, dismissed: null);
      return update == null ? UpdateCheck.upToDate : UpdateCheck.available;
    } on Object catch (e) {
      debugPrint('[aggiornamenti] ${e.runtimeType}');
      return UpdateCheck.failed;
    }
  }

  @override
  Future<void> dismiss() async {
    final update = _available;
    if (update == null) return;
    await _settings.write(_dismissedKey, update.version);
    _show(null, dismissed: update.version);
  }

  @override
  Future<void> download() async {
    final update = _available;
    if (update == null) return;
    try {
      if (!await launch(update.url)) await launch(fallback);
    } on Object catch (e) {
      debugPrint('[aggiornamenti] ${e.runtimeType}');
    }
  }

  /// Reads the version file: the newer version, or null. The time is noted first, so a failing site is asked at most
  /// once a day too; a good answer is kept for the day.
  Future<AppUpdate?> _fetch() async {
    await _settings.write(_checkedKey, _clock.now().toIso8601String());
    if (!feed.isScheme('https')) throw const FormatException('not https');
    final request = http.Request('GET', feed)..followRedirects = false;
    final response = await http.Response.fromStream(await _http.send(request).timeout(_timeout)).timeout(_timeout);
    // A redirect comes back as it is, and is refused here like any other status.
    if (response.statusCode != 200) throw http.ClientException('status ${response.statusCode}', feed);
    final update = _newer(response.body);
    await _settings.write(_foundKey, response.body);
    return update;
  }

  /// The version in [body] if its build is above the installed one; throws [FormatException] on a malformed file.
  AppUpdate? _newer(String? body) {
    if (body == null) return null;
    if (jsonDecode(body) case {'version': final String version, 'build': final int build, 'url': final String url}
        when RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      final uri = Uri.parse(url);
      if (!uri.isScheme('https') && !uri.isScheme('itms-beta')) throw const FormatException('url');
      return build > installed ? (version: version, url: uri) : null;
    }
    throw const FormatException('version file');
  }

  void _show(AppUpdate? update, {required String? dismissed}) {
    final shown = update?.version == dismissed ? null : update;
    if (shown == _available) return;
    _available = shown;
    _changes.add(shown);
  }
}
