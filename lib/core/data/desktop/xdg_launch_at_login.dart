import 'package:file/file.dart';

import '../../domain/launch_at_login.dart';

/// Linux: an XDG autostart entry, `$XDG_CONFIG_HOME/autostart/postino.desktop` ([_entry]), starting [_executable]
/// with [hidden] (#239); [_arguments] is this run's command line.
class XdgLaunchAtLogin(final File _entry, final String _executable, final List<String> _arguments)
    implements LaunchAtLogin {
  /// What the entry passes: the window stays hidden in the tray (`linux/runner/my_application.cc`).
  static const hidden = '--hidden';

  /// What a desktop writes to turn the entry off without deleting it (GNOME: the second).
  static const _off = {'Hidden=true', 'X-GNOME-Autostart-enabled=false'};

  @override
  bool get supported => true;

  @override
  Future<bool> isEnabled() async =>
      _entry.existsSync() && !(await _entry.readAsLines()).map((l) => l.replaceAll(' ', '')).any(_off.contains);

  @override
  Future<void> setEnabled({required bool enabled}) async {
    if (!enabled) {
      if (_entry.existsSync()) await _entry.delete();
      return;
    }
    await _entry.parent.create(recursive: true);
    await _entry.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Postino\n'
      '$_exec\n'
      'X-GNOME-Autostart-enabled=true\n',
    );
  }

  @override
  Future<bool> launchedAtLogin() async => _arguments.contains(hidden);

  /// An entry written before #239 (this executable without [hidden]) gets it; the rest of the entry, a desktop's
  /// "off" included, stays. Failing leaves the entry as it was: it still starts Postino, with its window.
  void upgrade() {
    try {
      if (!_entry.existsSync()) return;
      final old = 'Exec=${_quoted(_executable)}';
      final lines = _entry.readAsLinesSync();
      if (!lines.contains(old)) return;
      _entry.writeAsStringSync('${[for (final l in lines) l == old ? _exec : l].join('\n')}\n');
    } on FileSystemException {
      return;
    }
  }

  String get _exec => 'Exec=${_quoted(_executable)} $hidden';

  /// Exec quoting (`"`, `` ` ``, `$`, `\` escaped inside double quotes; `%` doubled, or it reads as a field code),
  /// then the file's own escape of `\`.
  static String _quoted(String path) {
    final escaped = path.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}').replaceAll('%', '%%');
    return '"$escaped"'.replaceAll(r'\', r'\\');
  }
}
