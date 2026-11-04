// Avvio al login on Linux (#38): an XDG autostart entry.

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/desktop/xdg_launch_at_login.dart';

void main() {
  final fs = MemoryFileSystem();
  final entry = fs.file('/home/u/.config/autostart/postino.desktop');
  final login = XdgLaunchAtLogin(entry, '/opt/my apps/"postino"/postino');

  tearDown(() {
    if (entry.existsSync()) entry.deleteSync();
  });

  test('on writes the entry starting this executable, quoted; off removes it', () async {
    expect(await login.isEnabled(), isFalse);
    await login.setEnabled(enabled: true);
    expect(await login.isEnabled(), isTrue);
    expect(entry.readAsLinesSync(), contains(r'Exec="/opt/my apps/\\"postino\\"/postino"'));
    await login.setEnabled(enabled: false);
    expect(entry.existsSync(), isFalse);
    expect(await login.isEnabled(), isFalse);
  });

  test('turning off what is already off is fine', () async {
    await login.setEnabled(enabled: false);
    expect(await login.isEnabled(), isFalse);
  });

  test('an entry the desktop hid counts as off', () async {
    await login.setEnabled(enabled: true);
    entry.writeAsStringSync('${entry.readAsStringSync()}Hidden=true\n');
    expect(await login.isEnabled(), isFalse);
  });
}
