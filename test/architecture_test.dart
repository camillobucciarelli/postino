// Enforces ADR 0006 import rules by scanning every import/export under lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// Resolves a directive to a lib-relative path (`features/x/...`), or returns the raw URI for external ones.
String _target(String file, String uri) {
  if (uri.startsWith('package:postino/')) return uri.substring('package:postino/'.length);
  if (uri.contains(':')) return uri;
  return Uri.parse(file).resolve(uri).path;
}

String? _feature(String path) => path.startsWith('features/') ? path.split('/')[1] : null;

List<String> violations(String file, String source) {
  final out = <String>[];
  for (final m in _directive.allMatches(source)) {
    final t = _target(file, m.group(1)!);
    final segments = t.split('/');
    void bad(String why) => out.add('$file -> ${m.group(1)}: $why');

    final own = _feature(file);
    if (own != null && !t.contains(':') && _feature(t) != own &&
        !t.startsWith('core/') && !t.startsWith('design_system/')) {
      bad('features may import only their own feature, core and design_system');
    }
    if (file.split('/').contains('domain') &&
        (t.startsWith('package:flutter/') || t == 'dart:ui' ||
            segments.contains('data') || segments.contains('presentation'))) {
      bad('domain must be pure Dart');
    }
    if (file.startsWith('app/') && segments.contains('data')) bad('pages must not import data');
  }
  return out;
}

void main() {
  test('lib/ respects the ADR 0006 import rules', () {
    final found = <String>[
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          ...violations(f.path.replaceAll(r'\\', '/').substring('lib/'.length), f.readAsStringSync()),
    ];
    expect(found, isEmpty);
  });
}
