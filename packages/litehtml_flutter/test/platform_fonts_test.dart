import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/src/platform_fonts.dart';

void main() {
  test('le generiche diventano i font della piattaforma', () {
    expect(platformFonts('sans-serif', TargetPlatform.macOS), ['Helvetica']);
    expect(platformFonts('sans-serif', TargetPlatform.android), ['sans-serif']);
    expect(platformFonts('serif', TargetPlatform.windows), ['Times New Roman']);
    expect(platformFonts('monospace', TargetPlatform.linux), ['Liberation Mono', 'DejaVu Sans Mono']);
    expect(platformFonts('system-ui', TargetPlatform.iOS), ['.AppleSystemUIFont']);
  });

  test('un nome comune resta primo, seguito dalla sua generica; gli altri passano così', () {
    expect(platformFonts('"Helvetica Neue", Arial, sans-serif', TargetPlatform.android), [
      'Helvetica Neue',
      'sans-serif',
      'Arial',
    ]);
    expect(platformFonts("Georgia, 'Times New Roman'", TargetPlatform.linux), [
      'Georgia',
      'Liberation Serif',
      'DejaVu Serif',
      'Times New Roman',
    ]);
    expect(platformFonts('Figtree', TargetPlatform.windows), ['Figtree']);
    expect(platformFonts(' , ', TargetPlatform.macOS), isEmpty);
  });
}
