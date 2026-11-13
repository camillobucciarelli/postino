// Avvio al login on Linux (#38): an XDG autostart entry, starting Postino hidden in the tray (#239).

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/desktop/xdg_launch_at_login.dart';

void main() {
  final fs = MemoryFileSystem();
  final entry = fs.file('/home/u/.config/autostart/postino.desktop');
  final login = XdgLaunchAtLogin(entry, '/opt/my apps/"postino"/postino', const []);

  tearDown(() {
    if (entry.existsSync()) entry.deleteSync();
  });

  test('on writes the entry starting this executable, quoted, hidden; off removes it', () async {
    expect(await login.isEnabled(), isFalse);
    await login.setEnabled(enabled: true);
    expect(await login.isEnabled(), isTrue);
    expect(entry.readAsLinesSync(), contains(r'Exec="/opt/my apps/\\"postino\\"/postino" --hidden'));
    await login.setEnabled(enabled: false);
    expect(entry.existsSync(), isFalse);
    expect(await login.isEnabled(), isFalse);
  });

  test('turning off what is already off is fine', () async {
    await login.setEnabled(enabled: false);
    expect(await login.isEnabled(), isFalse);
  });

  for (final off in ['Hidden=true', 'X-GNOME-Autostart-enabled=false']) {
    test('an entry the desktop turned off with $off counts as off', () async {
      await login.setEnabled(enabled: true);
      entry.writeAsStringSync('${entry.readAsStringSync()}$off\n');
      expect(await login.isEnabled(), isFalse);
    });
  }

  test('a % in the path is doubled, not read as a field code', () async {
    await XdgLaunchAtLogin(entry, '/opt/100%postino/postino', const []).setEnabled(enabled: true);
    expect(entry.readAsLinesSync(), contains('Exec="/opt/100%%postino/postino" --hidden'));
  });

  test('a run started by the entry is told apart from one started by the user', () async {
    expect(await XdgLaunchAtLogin(entry, '/opt/postino', const ['--hidden']).launchedAtLogin(), isTrue);
    expect(await login.launchedAtLogin(), isFalse);
  });

  group('an entry written before #239', () {
    const old = '[Desktop Entry]\nType=Application\nName=Postino\nExec="/opt/postino"\nHidden=true\n';
    final upgraded = XdgLaunchAtLogin(entry, '/opt/postino', const []);

    test('gets the argument, the rest of it kept', () {
      entry
        ..createSync(recursive: true)
        ..writeAsStringSync(old);
      upgraded.upgrade();
      expect(entry.readAsLinesSync(), [
        '[Desktop Entry]',
        'Type=Application',
        'Name=Postino',
        'Exec="/opt/postino" --hidden',
        'Hidden=true',
      ]);
    });

    test('of another executable stays as it is', () {
      entry
        ..createSync(recursive: true)
        ..writeAsStringSync(old);
      XdgLaunchAtLogin(entry, '/elsewhere/postino', const []).upgrade();
      expect(entry.readAsStringSync(), old);
    });

    test('missing, nothing is written', () {
      upgraded.upgrade();
      expect(entry.existsSync(), isFalse);
    });
  });
}
