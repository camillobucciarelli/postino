import 'dart:async';
import 'dart:io' show Process, ProcessException;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../domain/system_tray.dart';

/// The tray icon through tray_manager's native API (nativeapi).
@LazySingleton(as: SystemTray, env: [Environment.prod])
class NativeSystemTray() implements SystemTray {
  // macOS wants a monochrome template image, the others the coloured logo (docs/brand-icone.md).
  static const _asset = 'assets/tray/tray_icon.png';
  static const _templateAsset = 'assets/tray/tray_icon_template.png';

  final _commands = StreamController<TrayCommand>.broadcast();

  // Kept while shown: a wrapper that is garbage-collected removes the icon or drops its listener.
  final _nativeHandles = <Object>[];

  @override
  Stream<TrayCommand> get commands => _commands.stream;

  @override
  Future<void> show({required String tooltip, required String openLabel, required String quitLabel}) async {
    if (_nativeHandles.isNotEmpty) return;
    if (defaultTargetPlatform == TargetPlatform.linux && !await _linuxHasWatcher()) {
      throw StateError('no StatusNotifierWatcher');
    }
    final icon = TrayIcon.create() ?? (throw StateError('no tray icon'));
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final image = ImageAsset.fromAsset(isMac ? _templateAsset : _asset) ?? (throw StateError('no tray image'));
    final menu = Menu.create() ?? (throw StateError('no tray menu'));
    final open = _item(openLabel, TrayCommand.open);
    final quit = _item(quitLabel, TrayCommand.quit);
    menu
      ..addItem(open)
      ..addSeparator()
      ..addItem(quit);
    icon
      ..icon = image
      // macOS: the template is tinted by the menu bar (light, dark, highlighted); the PNG is 36 px, the 18 pt default @2x.
      ..isIconTemplate = isMac
      ..setTooltip(tooltip)
      ..setContextMenu(menu)
      // macOS: a click opens the menu, like every menu bar item. Windows: a click opens the window, the right
      // click the menu. Linux: the panel opens the menu itself and reports no clicks.
      ..setContextMenuTrigger(
        defaultTargetPlatform == TargetPlatform.macOS ? ContextMenuTrigger.clicked : ContextMenuTrigger.rightClicked,
      )
      // Listened to on every platform, the check inside: behind an `if` on the platform the AOT compiler drops the
      // listener off Windows, and the Dart 3.13 snapshotter then aborts on cnativeapi's half-shaken
      // `native_tray_icon_event_t` ("Class with illegal cid", release builds of macOS, Linux, iOS).
      ..addListener((event) {
        if (event is TrayIconClickedEvent && defaultTargetPlatform == TargetPlatform.windows) {
          _commands.add(TrayCommand.open);
        }
      });
    if (!icon.setVisible(true)) throw StateError('tray icon not shown');
    _nativeHandles.addAll([icon, menu, open, quit]);
  }

  /// Windows keeps a ghost icon in the notification area until the mouse passes over it, unless it is removed.
  @override
  Future<void> hide() async {
    for (final icon in _nativeHandles.whereType<TrayIcon>()) {
      icon.dispose();
    }
    _nativeHandles.clear();
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
