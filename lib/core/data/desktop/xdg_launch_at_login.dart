import 'package:file/file.dart';

import '../../domain/launch_at_login.dart';

/// Linux: an XDG autostart entry, `$XDG_CONFIG_HOME/autostart/postino.desktop` ([_entry]), starting [_executable].
class XdgLaunchAtLogin(final File _entry, final String _executable) implements LaunchAtLogin {
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
      'Exec=${_quoted(_executable)}\n'
      'X-GNOME-Autostart-enabled=true\n',
    );
  }

  /// Exec quoting (`"`, `` ` ``, `$`, `\` escaped inside double quotes; `%` doubled, or it reads as a field code),
  /// then the file's own escape of `\`.
  static String _quoted(String path) {
    final escaped = path.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}').replaceAll('%', '%%');
    return '"$escaped"'.replaceAll(r'\', r'\\');
  }
}
