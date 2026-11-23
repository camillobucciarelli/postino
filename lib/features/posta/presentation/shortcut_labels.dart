import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../i18n/strings.g.dart';
import 'posta_shortcuts.dart';

/// The keys of [action] as a tooltip says them, from [postaShortcuts]: «R», «#», «⇧U» on macOS and «Maiusc+U»
/// elsewhere; null when it has none.
String? shortcutLabel(BuildContext context, PostaAction action) {
  final s = postaShortcuts.where((s) => s.action == action && !s.listOnly).firstOrNull;
  if (s == null) return null;
  final mac = defaultTargetPlatform == TargetPlatform.macOS;
  final key = s.character ?? s.key!.keyLabel.toUpperCase();
  final modifiers = [if (s.command) mac ? '⌘' : 'Ctrl', if (s.shift) mac ? '⇧' : context.t.azioni.shiftKey];
  return mac ? '${modifiers.join()}$key' : [...modifiers, key].join('+');
}
