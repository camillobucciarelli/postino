// A new version of Postino on Android and iOS (#287): the site's version file, read at most once a day over HTTPS
// with no redirect, compared by build number. No network: a MockClient answers.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/site_app_updater.dart';
import 'package:postino/core/domain/app_updater.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_platform.dart';

final _feed = Uri.parse('https://postino.example/android/latest/version.json');
final _apk = Uri.parse('https://postino.example/android/1.3.0/Postino-1.3.0.apk');
final _guide = Uri.parse('https://postino.example/guida/index.html');
const _installed = 1002001;

/// What «Cerca aggiornamenti» found; null when it failed.
Future<UpdateCheck?> _check(SiteAppUpdater u) async => switch (await u.checkForUpdates()) {
  Ok(:final value) => value,
  Err() => null,
};

String _file({String version = '1.3.0', Object build = 1003000, String? url}) =>
    jsonEncode({'version': version, 'build': build, 'url': url ?? '$_apk'});

void main() {
  late PostinoDatabase db;
  late FakeClock clock;
  late List<http.BaseRequest> requests;
  late http.Response Function() reply;
  late List<Uri> launched;
  var opens = true;

  SiteAppUpdater updater({Uri? feed, http.Client? client}) => SiteAppUpdater(
    client ??
        MockClient((r) async {
          requests.add(r);
          return reply();
        }),
    db.deviceSettingsDao,
    clock,
    feed: feed ?? _feed,
    installed: _installed,
    launch: (url) async {
      launched.add(url);
      return opens;
    },
    fallback: _guide,
  );

  setUp(() {
    db = PostinoDatabase.inMemory();
    clock = FakeClock(DateTime.utc(2026, 11, 14, 9));
    requests = [];
    launched = [];
    opens = true;
    reply = () => http.Response(_file(), 200);
  });
  tearDown(() => db.close());

  group('the build on the site against the installed one', () {
    test('supported, and the Banner hears of a version once, not at every check that finds it again', () async {
      final u = updater();
      expect(u.supported, isTrue);
      final shown = <AppUpdate?>[];
      u.changes.listen(shown.add);
      await u.checkForUpdates();
      await u.checkForUpdates();
      await pumpEventQueue();
      expect(shown, [(version: '1.3.0', url: _apk)]);
    });

    test('newer: available, named by its version', () async {
      final u = updater();
      expect(await _check(u), UpdateCheck.available);
      expect(u.available, (version: '1.3.0', url: _apk));
    });

    for (final (name, build) in [('the same', _installed), ('older', _installed - 1)]) {
      test('$name: up to date, nothing available', () async {
        reply = () => http.Response(_file(build: build), 200);
        final u = updater();
        expect(await _check(u), UpdateCheck.upToDate);
        expect(u.available, isNull);
      });
    }

    test('a malformed file (version_file_test.dart has the cases): failed, nothing available', () async {
      reply = () => http.Response('oops', 200);
      final u = updater();
      expect(await _check(u), isNull);
      expect(u.available, isNull);
    });

    test("iOS's App Store page is accepted (#323)", () async {
      final store = Uri.parse('https://apps.apple.com/app/id1234567890');
      reply = () => http.Response(_file(url: '$store'), 200);
      final u = updater();
      expect(await _check(u), UpdateCheck.available);
      expect(u.available?.url, store);
    });
  });

  group('the request', () {
    test('a fixed GET with nothing of the user, never following a redirect', () async {
      await updater().checkForUpdates();
      final r = requests.single;
      expect((r.method, r.url, r.followRedirects), ('GET', _feed, false));
      expect(r.url.query, isEmpty);
    });

    test('a redirect is refused: failed, nothing available', () async {
      reply = () => http.Response('', 302, headers: {'location': 'https://elsewhere.example/version.json'});
      final u = updater();
      expect(await _check(u), isNull);
      expect(u.available, isNull);
      expect(requests, hasLength(1));
    });

    test('a plain http feed is never asked', () async {
      final u = updater(feed: Uri.parse('http://postino.example/android/latest/version.json'));
      expect(await _check(u), isNull);
      expect(requests, isEmpty);
    });

    test('a site that does not answer is aborted after the timeout: failed, the connection let go', () {
      fakeAsync((async) {
        http.BaseRequest? sent;
        final u = updater(
          // Like IOClient: the request ends when its abortTrigger fires, and only then.
          client: MockClient.streaming((r, _) async {
            sent = r;
            await (r as http.Abortable).abortTrigger;
            throw http.RequestAbortedException(r.url);
          }),
        );
        UpdateCheck? check = UpdateCheck.shown;
        var done = false;
        unawaited(
          _check(u).then((c) {
            check = c;
            done = true;
          }),
        );
        async.elapse(SiteAppUpdater.timeout - const Duration(milliseconds: 1));
        expect(done, isFalse);
        expect(sent?.followRedirects, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue);
        expect(check, isNull);
        expect(u.available, isNull);
      });
    });

    test('no network: failed, nothing available', () async {
      reply = () => throw http.ClientException('offline');
      final u = updater();
      expect(await _check(u), isNull);
      expect(u.available, isNull);
    });
  });

  group('the daily check', () {
    test('asks the site at most once a day, then again', () async {
      final u = updater();
      await u.checkDaily();
      expect(u.available, isNotNull);
      clock.advance(const Duration(hours: 23, minutes: 59));
      await u.checkDaily();
      expect(requests, hasLength(1));
      clock.advance(const Duration(minutes: 1));
      await u.checkDaily();
      expect(requests, hasLength(2));
    });

    test('start and resume at once ask the site once', () async {
      final u = updater();
      await Future.wait([u.checkDaily(), u.checkDaily()]);
      expect(requests, hasLength(1));
    });

    test('a failure counts too: no second request that day, no Banner, no error', () async {
      reply = () => http.Response('', 500);
      final u = updater();
      await u.checkDaily();
      expect(u.available, isNull);
      reply = () => http.Response(_file(), 200);
      await u.checkDaily();
      expect(requests, hasLength(1));
      expect(u.available, isNull);
    });

    test('after a restart within the day, the last answer shows without asking again', () async {
      await updater().checkDaily();
      final again = updater();
      await again.checkDaily();
      expect(requests, hasLength(1));
      expect(again.available?.version, '1.3.0');
    });

    test('a clock moved back counts as a day gone', () async {
      final u = updater();
      await u.checkDaily();
      clock.current = clock.current.subtract(const Duration(minutes: 1));
      await u.checkDaily();
      expect(requests, hasLength(2));
    });

    test('«Cerca aggiornamenti» asks now, whatever the day', () async {
      final u = updater();
      await u.checkDaily();
      await u.checkForUpdates();
      expect(requests, hasLength(2));
    });
  });

  group('closing the Banner', () {
    test('hides that version for good, even after a restart and the next day', () async {
      final u = updater();
      await u.checkDaily();
      final shown = <AppUpdate?>[];
      u.changes.listen(shown.add);
      await u.dismiss();
      expect(u.available, isNull);
      await pumpEventQueue();
      expect(shown, [null]);

      clock.advance(const Duration(days: 2));
      final again = updater();
      await again.checkDaily();
      expect(requests, hasLength(2));
      expect(again.available, isNull);
    });

    test('a newer version shows again', () async {
      final u = updater();
      await u.checkDaily();
      await u.dismiss();
      reply = () => http.Response(_file(version: '1.4.0', build: 1004000), 200);
      clock.advance(const Duration(days: 1));
      await u.checkDaily();
      expect(u.available?.version, '1.4.0');
    });

    test('«Cerca aggiornamenti» shows it again', () async {
      final u = updater();
      await u.checkDaily();
      await u.dismiss();
      expect(await _check(u), UpdateCheck.available);
      expect(u.available?.version, '1.3.0');
    });
  });

  group('«Aggiorna»', () {
    test("opens the version's url", () async {
      final u = updater();
      await u.checkForUpdates();
      await u.download();
      expect(launched, [_apk]);
    });

    test('falls back on the guide when it does not open (TestFlight missing)', () async {
      opens = false;
      final u = updater();
      await u.checkForUpdates();
      await u.download();
      expect(launched, [_apk, _guide]);
    });

    test('a launcher that throws is swallowed: no error, no second try', () async {
      final u = SiteAppUpdater(
        MockClient((_) async => http.Response(_file(), 200)),
        db.deviceSettingsDao,
        clock,
        feed: _feed,
        installed: _installed,
        launch: (url) async {
          launched.add(url);
          throw Exception('no activity');
        },
        fallback: _guide,
      );
      await u.checkForUpdates();
      await expectLater(u.download(), completes);
      expect(launched, [_apk]);
    });

    test('nothing to open without a version', () async {
      await updater().download();
      expect(launched, isEmpty);
    });
  });
}
