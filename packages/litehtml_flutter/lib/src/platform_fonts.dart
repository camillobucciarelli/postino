import 'package:flutter/foundation.dart';

enum _Kind() {
  sans,
  serif,
  mono,
  system,
}

/// Nomi CSS comuni nelle email, per famiglia generica.
const _kinds = {
  'sans-serif': _Kind.sans,
  'arial': _Kind.sans,
  'helvetica': _Kind.sans,
  'helvetica neue': _Kind.sans,
  'verdana': _Kind.sans,
  'tahoma': _Kind.sans,
  'trebuchet ms': _Kind.sans,
  'segoe ui': _Kind.sans,
  'roboto': _Kind.sans,
  'serif': _Kind.serif,
  'times': _Kind.serif,
  'times new roman': _Kind.serif,
  'georgia': _Kind.serif,
  'garamond': _Kind.serif,
  'cambria': _Kind.serif,
  'monospace': _Kind.mono,
  'courier': _Kind.mono,
  'courier new': _Kind.mono,
  'consolas': _Kind.mono,
  'menlo': _Kind.mono,
  'monaco': _Kind.mono,
  'lucida console': _Kind.mono,
  'system-ui': _Kind.system,
  '-apple-system': _Kind.system,
  'blinkmacsystemfont': _Kind.system,
};

/// Nomi che non sono un font: solo la loro traduzione.
const _generic = {'sans-serif', 'serif', 'monospace', 'system-ui', '-apple-system', 'blinkmacsystemfont'};

/// Font installati per famiglia generica: macOS/iOS col nome di sistema, Android con gli alias di `fonts.xml`,
/// Windows con i font di base, Linux con Liberation (metriche di Arial/Times/Courier) e DejaVu.
List<String> _installed(_Kind kind, TargetPlatform platform) => switch ((kind, platform)) {
  (_Kind.sans, TargetPlatform.macOS || TargetPlatform.iOS) => const ['Helvetica'],
  (_Kind.serif, TargetPlatform.macOS || TargetPlatform.iOS) => const ['Times New Roman'],
  (_Kind.mono, TargetPlatform.macOS || TargetPlatform.iOS) => const ['Courier New'],
  (_Kind.system, TargetPlatform.macOS || TargetPlatform.iOS) => const ['.AppleSystemUIFont'],
  (_Kind.sans || _Kind.system, TargetPlatform.android || TargetPlatform.fuchsia) => const ['sans-serif'],
  (_Kind.serif, TargetPlatform.android || TargetPlatform.fuchsia) => const ['serif'],
  (_Kind.mono, TargetPlatform.android || TargetPlatform.fuchsia) => const ['monospace'],
  (_Kind.sans, TargetPlatform.windows) => const ['Arial'],
  (_Kind.serif, TargetPlatform.windows) => const ['Times New Roman'],
  (_Kind.mono, TargetPlatform.windows) => const ['Courier New'],
  (_Kind.system, TargetPlatform.windows) => const ['Segoe UI'],
  (_Kind.sans || _Kind.system, TargetPlatform.linux) => const ['Liberation Sans', 'DejaVu Sans'],
  (_Kind.serif, TargetPlatform.linux) => const ['Liberation Serif', 'DejaVu Serif'],
  (_Kind.mono, TargetPlatform.linux) => const ['Liberation Mono', 'DejaVu Sans Mono'],
};

/// Le famiglie da provare, in ordine, per un `font-family` CSS (lista separata da virgole) su [platform].
///
/// Una generica diventa i font installati della piattaforma; un nome comune (Arial, Georgia…) resta primo, seguito
/// dai font della sua generica, così dove manca si ripiega sulla stessa famiglia e non sul font dell'app.
// ponytail: tabelle verificate solo su macOS; Windows, Linux e Android sono i nomi documentati dei font di base.
List<String> platformFonts(String cssFamily, [TargetPlatform? platform]) {
  final target = platform ?? defaultTargetPlatform;
  final out = <String>{};
  for (final raw in cssFamily.split(',')) {
    final name = raw.trim().replaceAll('"', '').replaceAll("'", '');
    if (name.isEmpty) continue;
    final kind = _kinds[name.toLowerCase()];
    if (!_generic.contains(name.toLowerCase())) out.add(name);
    if (kind != null) out.addAll(_installed(kind, target));
  }
  return out.toList();
}
