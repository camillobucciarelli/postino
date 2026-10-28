// Enforces ADR 0006 import rules by scanning every import/export under lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(r'^\s*(?:import|export)\s[^;]*;', multiLine: true);
final _uri = RegExp(r'''['"]([^'"]+)['"]''');

/// Packages that pull in Flutter; `domain` must stay pure Dart.
// ponytail: name-based denylist, extend when a new Flutter-only package without "flutter" in its name is added.
bool _flutterDependent(String uri) =>
    uri == 'dart:ui' ||
    uri.split('/').first.contains('flutter') ||
    uri.startsWith('package:routefly/');

/// Resolves a directive to a lib-relative path (`features/x/...`), or returns the raw URI for external ones.
String _target(String file, String uri) {
  if (uri.startsWith('package:postino/')) {
    return uri.substring('package:postino/'.length);
  }
  if (uri.contains(':')) return uri;
  return Uri.parse(file).resolve(uri).path;
}

String? _feature(String path) =>
    path.startsWith('features/') ? path.split('/')[1] : null;

/// `lib/x/y.dart` or `lib\x\y.dart` -> `x/y.dart`.
String libPath(String path) =>
    path.replaceAll(r'\', '/').substring('lib/'.length);

List<String> violations(String file, String source) {
  final out = <String>[];
  for (final uri in [
    for (final d in _directive.allMatches(source))
      for (final u in _uri.allMatches(d.group(0)!)) u.group(1)!,
  ]) {
    final t = _target(file, uri);
    final segments = t.split('/');
    void bad(String why) => out.add('$file -> $uri: $why');

    final own = _feature(file);
    if (own != null &&
        !t.contains(':') &&
        _feature(t) != own &&
        !t.startsWith('core/') &&
        !t.startsWith('design_system/') &&
        !(t.startsWith('i18n/') && file.split('/').contains('presentation'))) {
      bad(
        'features may import only their own feature, core, design_system '
        '(and i18n from presentation)',
      );
    }
    if (file.split('/').contains('domain') &&
        (_flutterDependent(t) ||
            (!t.contains(':') && !segments.contains('domain')) ||
            segments.contains('data') ||
            segments.contains('presentation'))) {
      bad('domain must be pure Dart');
    }
    if (file.startsWith('app/') && segments.contains('data')) {
      bad('pages must not import data');
    }
  }
  return out;
}

void main() {
  group('violations', () {
    test('presentation may import i18n', () {
      expect(
        violations(
          'features/posta/presentation/inbox.dart',
          "import '../../../i18n/strings.g.dart';",
        ),
        isEmpty,
      );
    });
    test('domain may not import i18n', () {
      expect(
        violations(
          'features/posta/domain/mail.dart',
          "import 'package:postino/i18n/strings.g.dart';",
        ),
        isNotEmpty,
      );
    });
    test('data may not import i18n', () {
      expect(
        violations(
          'features/posta/data/repo.dart',
          "import '../../../i18n/strings.g.dart';",
        ),
        isNotEmpty,
      );
    });
    for (final uri in [
      'package:flutter/widgets.dart',
      'dart:ui',
      'package:signals_flutter/signals_flutter.dart',
      'package:flutter_localizations/flutter_localizations.dart',
      'package:slang_flutter/slang_flutter.dart',
      'package:routefly/routefly.dart',
    ]) {
      test('domain may not import $uri', () {
        expect(violations('core/domain/x.dart', "import '$uri';"), isNotEmpty);
      });
    }
    test('domain may import pure Dart packages', () {
      expect(
        violations('core/domain/x.dart', "import 'package:meta/meta.dart';"),
        isEmpty,
      );
    });
    for (final uri in [
      '../../design_system/tokens/postino_tokens.dart',
      'package:postino/i18n/strings.g.dart',
      'package:postino/main.dart',
    ]) {
      test('domain may not import non-domain in-repo $uri', () {
        expect(
          violations('core/domain/x.dart', "import '$uri';"),
          isNotEmpty,
        );
      });
    }
    test('feature domain may import core/domain', () {
      expect(
        violations(
          'features/posta/domain/mail.dart',
          "import 'package:postino/core/domain/result.dart';",
        ),
        isEmpty,
      );
    });
    test('feature domain may import its own domain', () {
      expect(
        violations('features/posta/domain/mail.dart', "import 'address.dart';"),
        isEmpty,
      );
    });
    test('both branches of a conditional import are checked', () {
      expect(
        violations(
          'core/domain/x.dart',
          "import 'stub.dart' if (dart.library.ui) 'package:flutter/widgets.dart';",
        ),
        isNotEmpty,
      );
    });
    test('Windows paths are normalised', () {
      expect(
        libPath(r'lib\features\posta\domain\x.dart'),
        'features/posta/domain/x.dart',
      );
    });
  });

  test('lib/ respects the ADR 0006 import rules', () {
    final found = <String>[
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          ...violations(libPath(f.path), f.readAsStringSync()),
    ];
    expect(found, isEmpty);
  });
}
