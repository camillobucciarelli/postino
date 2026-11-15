// The Mac App Store variant (#325, ADR 0021) is the DMG's app without Sparkle: its Info.plist and entitlements are the
// DMG's minus Sparkle's keys, so a key added to one and forgotten in the other fails here. Its bundle id is iOS's
// (universal purchase).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test("Store-Info.plist is Info.plist without Sparkle's SU* keys", () {
    final dmg = _read('macos/Runner/Info.plist');
    final sparkle = RegExp(r'\t<key>SU\w+</key>\n\t<(?:string>[^<]*</string|true/)>\n');
    expect(sparkle.allMatches(dmg), hasLength(5));
    expect(_read('macos/Runner/Store-Info.plist'), dmg.replaceAll(sparkle, ''));
  });

  test("Store.entitlements is Release.entitlements without Sparkle's mach-lookup exceptions", () {
    final dmg = _read('macos/Runner/Release.entitlements');
    final sparkle = RegExp(
      r'\t<key>com\.apple\.security\.temporary-exception\.mach-lookup\.global-name</key>\n\t<array>\n'
      r'(?:\t\t<string>[^<]*</string>\n)+\t</array>\n',
    );
    expect(sparkle.hasMatch(dmg), isTrue);
    expect(_read('macos/Runner/Store.entitlements'), dmg.replaceAll(sparkle, ''));
  });

  test('the bundle id is the iOS one', () {
    final macos = RegExp(r'^PRODUCT_BUNDLE_IDENTIFIER = (\S+)$', multiLine: true);
    final ios = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);');
    final id = macos.firstMatch(_read('macos/Runner/Configs/AppInfo.xcconfig'))!.group(1);
    final iosIds = ios.allMatches(_read('ios/Runner.xcodeproj/project.pbxproj')).map((m) => m.group(1)).toSet();
    expect(iosIds, contains(id));
  });
}
