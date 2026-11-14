// The release's version file (#287): newer, same, older or malformed against the installed build.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/version_file.dart';

const _installed = 1002001;
final _apk = Uri.parse('https://postino.example/android/1.3.0/Postino-1.3.0.apk');

String _file({String version = '1.3.0', Object build = 1003000, String? url}) =>
    jsonEncode({'version': version, 'build': build, 'url': url ?? '$_apk'});

void main() {
  test('a newer build: its version and url', () {
    expect(newerVersion(_file(), installed: _installed), (version: '1.3.0', url: _apk));
  });

  for (final (name, build) in [('the same', _installed), ('an older', _installed - 1)]) {
    test('$name build: nothing', () {
      expect(newerVersion(_file(build: build), installed: _installed), isNull);
    });
  }

  test("iOS's TestFlight url", () {
    expect(newerVersion(_file(url: 'itms-beta://'), installed: _installed)?.url, Uri.parse('itms-beta://'));
  });

  for (final (name, body) in [
    ('not JSON', 'oops'),
    ('a list', '[]'),
    ('no build', jsonEncode({'version': '1.3.0', 'url': '$_apk'})),
    ('a build in letters', _file(build: '1003000')),
    ('a version that is not X.Y.Z', _file(version: '1.3.0 <b>')),
    ('a plain http url', _file(url: 'http://postino.example/p.apk')),
    ('a javascript url', _file(url: 'javascript:alert(1)')),
  ]) {
    test('malformed, $name: FormatException', () {
      expect(() => newerVersion(body, installed: _installed), throwsFormatException);
    });
  }
}
