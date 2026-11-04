import 'package:file/file.dart';

import '../../domain/launch_at_login.dart';

/// Linux: an XDG autostart entry, `$XDG_CONFIG_HOME/autostart/postino.desktop` ([_entry]), starting [_executable].
class XdgLaunchAtLogin(final File _entry, final String _executable) implements LaunchAtLogin {
  @override
  bool get supported => true;

  /// A desktop that turns autostart off without deleting the entry writes `Hidden=true`.
  @override
  Future<bool> isEnabled() async =>
      _entry.existsSync() && !(await _entry.readAsLines()).any((l) => l.replaceAll(' ', '') == 'Hidden=true');

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

  /// Exec quoting (`"`, `` ` ``, `$`, `\` escaped inside double quotes), then the file's own escape of `\`.
  static String _quoted(String path) =>
      '"${path.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}')}"'.replaceAll(r'\', r'\\');
}
