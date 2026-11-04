import 'dart:async';
import 'dart:io' show Process, ProcessException;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../domain/system_tray.dart';

/// The tray icon through tray_manager's native API (nativeapi).
@LazySingleton(as: SystemTray, env: [Environment.prod])
class NativeSystemTray() implements SystemTray {
  static const _asset = 'assets/tray/tray_icon.png';

  final _commands = StreamController<TrayCommand>.broadcast();

  // Kept while shown: a wrapper that is garbage-collected removes the icon or drops its listener.
  final _held = <Object>[];

  @override
  Stream<TrayCommand> get commands => _commands.stream;

  @override
  Future<void> show({required String tooltip, required String openLabel, required String quitLabel}) async {
    if (_held.isNotEmpty) return;
    if (defaultTargetPlatform == TargetPlatform.linux && !await _linuxHasWatcher()) {
      throw StateError('no StatusNotifierWatcher');
    }
    final icon = TrayIcon.create() ?? (throw StateError('no tray icon'));
    final image = ImageAsset.fromAsset(_asset) ?? (throw StateError('no tray image'));
    final menu = Menu.create() ?? (throw StateError('no tray menu'));
    final open = _item(openLabel, TrayCommand.open);
    final quit = _item(quitLabel, TrayCommand.quit);
    menu
      ..addItem(open)
      ..addSeparator()
      ..addItem(quit);
    icon
      ..icon = image
      ..setTooltip(tooltip)
      ..setContextMenu(menu)
      // macOS: a click opens the menu, like every menu bar item. Windows: a click opens the window, the right
      // click the menu. Linux: the panel opens the menu itself and reports no clicks.
      ..setContextMenuTrigger(
        defaultTargetPlatform == TargetPlatform.macOS ? ContextMenuTrigger.clicked : ContextMenuTrigger.rightClicked,
      );
    if (defaultTargetPlatform == TargetPlatform.windows) {
      icon.addListener((event) {
        if (event is TrayIconClickedEvent) _commands.add(TrayCommand.open);
      });
    }
    if (!icon.setVisible(true)) throw StateError('tray icon not shown');
    _held.addAll([icon, menu, open, quit]);
  }

  MenuItem _item(String label, TrayCommand command) {
    return (MenuItem.createWithLabelAndType(label, MenuItemType.normal) ?? (throw StateError('no menu item')))
      ..addListener((event) {
        if (event is MenuItemClickedEvent) _commands.add(command);
      });
  }

  /// Linux shows the icon only through a StatusNotifierWatcher: GNOME has none without the AppIndicator extension,
  /// and there the icon would never appear and a hidden window could not come back. nativeapi does not tell.
  static Future<bool> _linuxHasWatcher() async {
    for (final name in const ['org.kde.StatusNotifierWatcher', 'com.canonical.StatusNotifierWatcher']) {
      try {
        final r = await Process.run('gdbus', [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.DBus',
          '--object-path',
          '/org/freedesktop/DBus',
          '--method',
          'org.freedesktop.DBus.NameHasOwner',
          name,
        ]);
        if (r.exitCode == 0 && '${r.stdout}'.contains('true')) return true;
      } on ProcessException {
        return false;
      }
    }
    return false;
  }
}
