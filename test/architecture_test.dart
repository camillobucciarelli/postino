// Enforces ADR 0006 import rules by scanning every import/export under lib/,
// plus the design system's: its levels, and no raw styling in features and pages.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Lookbehind, not `(?:^|;)`: the previous match already consumed its `;`.
final _directive = RegExp(
  r'(?:^|(?<=;))\s*(?:import|export)\s[^;]*;',
  multiLine: true,
);
// ponytail: regex strip, so a string literal containing `//` or `; import ...` is mis-read; use package:analyzer if that ever matters.
final _comment = RegExp(r'//.*|/\*[\s\S]*?\*/');
final _uri = RegExp(r'''['"]([^'"]+)['"]''');

/// Packages that pull in Flutter; `domain` must stay pure Dart.
// ponytail: name-based denylist, extend when a new Flutter-only package without "flutter" in its name is added.
bool _flutterDependent(String uri) =>
    uri == 'dart:ui' ||
    // Pure Dart despite its name (dart_quill_delta and html only).
    uri.split('/').first.contains('flutter') &&
        !uri.startsWith('package:flutter_quill_delta_from_html/') ||
    uri.startsWith('package:routefly/');

/// Resolves a directive to a lib-relative path (`features/x/...`), or returns the raw URI for external ones.
String _target(String file, String uri) {
  if (uri.startsWith('package:postino/')) {
    return Uri.parse(uri.substring('package:postino/'.length))
        .normalizePath()
        .path;
  }
  if (uri.contains(':')) return uri;
  return Uri.parse(file).resolve(uri).path;
}

/// Design system levels, bottom up: a level imports only those below it.
const _levels = ['tokens', 'atoms', 'molecules', 'organisms', 'templates'];

int _level(String path) {
  final s = path.split('/');
  return s.length > 2 && s.first == 'design_system'
      ? _levels.indexOf(s[1])
      : -1;
}

String? _feature(String path) =>
    path.startsWith('features/') ? path.split('/')[1] : null;

/// `lib/x/y.dart` or `lib\x\y.dart` -> `x/y.dart`.
String libPath(String path) =>
    path.replaceAll(r'\', '/').substring('lib/'.length);

List<String> violations(String file, String source) {
  final out = <String>[];
  for (final uri in [
    for (final d in _directive.allMatches(source.replaceAll(_comment, ' ')))
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
    if (file.startsWith('design_system/') &&
        ['core/', 'features/', 'app/'].any(t.startsWith)) {
      bad('the design system knows no app code');
    }
    if (_level(file) >= 0 && _level(t) > _level(file)) {
      bad('a design system level imports only the levels below it');
    }
    final isUi =
        file.startsWith('app/') || file.split('/').contains('presentation');
    if (file.startsWith('app/') && segments.contains('data')) {
      bad('pages must not import data');
    }
    if (isUi && t.startsWith('core/data/')) {
      bad('presentation and pages must not import core/data');
    }
    // ADR 0003: the UI reads only from the local database, never from a Provider.
    if (isUi && t.endsWith('core/domain/mail_provider.dart')) {
      bad('the UI must not import the Provider interface');
    }
    // ADR 0002: the choice of adapter lives in one factory, not in switches across core/data.
    if (file.startsWith('core/data/') &&
        file != 'core/data/sync/provider_factory.dart' &&
        t.endsWith('core/data/gmail/gmail_provider.dart')) {
      bad('only the provider factory may import a concrete Provider');
    }
  }
  return out;
}

final _rawStyle = RegExp(
  r'\bColors\.|\bColor\(|\bIcons\.|\bCupertinoIcons\.|\bTextStyle\(|\bFontWeight\.|\bfontSize:',
);

/// Features and pages draw only through the design system: no raw colors, icons or type.
List<String> styleViolations(String file, String source) => [
  if ((file.startsWith('features/') || file.startsWith('app/')) &&
      !file.endsWith('.g.dart'))
    for (final m in _rawStyle.allMatches(source.replaceAll(_comment, ' ')))
      '$file: ${m.group(0)} outside the design system',
];

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
      'package:postino/core/domain/../../i18n/strings.g.dart',
      'package:postino/core/domain/../../design_system/tokens/postino_tokens.dart',
    ]) {
      test('domain may not import non-domain in-repo $uri', () {
        expect(violations('core/domain/x.dart', "import '$uri';"), isNotEmpty);
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
    test('presentation must not import core/data', () {
      for (final uri in [
        '../../../core/data/attachment_cache.dart',
        'package:postino/core/data/attachment_cache.dart',
      ]) {
        expect(
          violations('features/posta/presentation/x.dart', "import '$uri';"),
          isNotEmpty,
        );
      }
    });
    test('pages must not import core/data', () {
      expect(
        violations(
          'app/posta/posta_layout.dart',
          "import 'package:postino/core/data/sync_engine.dart';",
        ),
        contains(contains('must not import core/data')),
      );
    });
    test('presentation may import core/domain', () {
      expect(
        violations(
          'features/posta/presentation/x.dart',
          "import 'package:postino/core/domain/file_name.dart';",
        ),
        isEmpty,
      );
    });
    test('every directive on a single line is checked', () {
      expect(
        violations(
          'core/domain/x.dart',
          "import 'dart:async'; import 'package:flutter/widgets.dart';",
        ),
        isNotEmpty,
      );
    });
    test('a block comment before an import does not hide it', () {
      expect(
        violations(
          'core/domain/x.dart',
          "/* pure */ import 'package:flutter/foundation.dart';",
        ),
        isNotEmpty,
      );
    });
    test('commented-out imports are ignored', () {
      expect(
        violations(
          'core/domain/x.dart',
          "// import 'package:flutter/widgets.dart';\n/* import 'dart:ui'; */",
        ),
        isEmpty,
      );
    });
    test('multi-line show imports are checked', () {
      expect(
        violations(
          'core/domain/x.dart',
          "import 'dart:async';\nimport 'package:flutter/widgets.dart'\n    show Widget,\n        State;",
        ),
        isNotEmpty,
      );
    });
    for (final file in [
      'features/posta/presentation/inbox.dart',
      'app/posta/posta_layout.dart',
    ]) {
      for (final uri in [
        'package:postino/core/domain/mail_provider.dart',
        '../../core/domain/mail_provider.dart',
      ]) {
        test('$file may not import the Provider interface ($uri)', () {
          expect(violations(file, "import '$uri';"), isNotEmpty);
        });
      }
    }
    test('the sync engine in core/data may import the Provider interface', () {
      expect(
        violations(
          'core/data/sync_engine.dart',
          "import '../domain/mail_provider.dart';",
        ),
        isEmpty,
      );
    });
    test('the provider factory may import a concrete Provider', () {
      expect(
        violations(
          'core/data/sync/provider_factory.dart',
          "import '../gmail/gmail_provider.dart';",
        ),
        isEmpty,
      );
    });
    for (final (file, uri) in [
      ('core/data/sync_engine.dart', 'gmail/gmail_provider.dart'),
      (
        'core/data/sync/outbox_sender.dart',
        'package:postino/core/data/gmail/gmail_provider.dart',
      ),
    ]) {
      test('$file may not import a concrete Provider ($uri)', () {
        expect(
          violations(file, "import '$uri';"),
          contains(contains('only the provider factory')),
        );
      });
    }
    for (final uri in [
      'package:postino/core/domain/account.dart',
      '../../features/posta/presentation/x.dart',
      'package:postino/app/posta/posta_layout.dart',
    ]) {
      test('the design system may not import $uri', () {
        expect(
          violations('design_system/atoms/x.dart', "import '$uri';"),
          isNotEmpty,
        );
      });
    }
    test('an atom may not import a molecule', () {
      expect(
        violations(
          'design_system/atoms/x.dart',
          "import '../molecules/postino_banner.dart';",
        ),
        isNotEmpty,
      );
    });
    test('a molecule may import atoms and tokens', () {
      expect(
        violations(
          'design_system/molecules/x.dart',
          "import '../atoms/postino_icon.dart';\nimport '../tokens/postino_theme.dart';",
        ),
        isEmpty,
      );
    });
    for (final code in [
      'Colors.red',
      'Color(0xFF000000)',
      'Icons.star',
      'CupertinoIcons.star',
      'TextStyle(color: c)',
      'FontWeight.bold',
      'Text(s, style: s.copyWith(fontSize: 3))',
    ]) {
      test('features may not draw with $code', () {
        expect(
          styleViolations('features/posta/presentation/x.dart', code),
          isNotEmpty,
        );
        expect(styleViolations('design_system/atoms/x.dart', code), isEmpty);
      });
    }
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
        if (f.path.endsWith('.dart')) ...[
          ...violations(libPath(f.path), f.readAsStringSync()),
          ...styleViolations(libPath(f.path), f.readAsStringSync()),
        ],
    ];
    expect(found, isEmpty);
  });
}
