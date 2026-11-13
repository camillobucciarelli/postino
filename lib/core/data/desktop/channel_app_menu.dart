import 'dart:async';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../domain/app_menu.dart';

/// macOS (`macos/Runner/MailMenu.swift`): the runner calls `refresh` on [channel] when «Aggiorna» is chosen, with
/// `true` when it came from Cmd+R. That one is left out: Flutter gets the key first and its Posta shortcut already
/// refreshed; the menu has it only when nothing took it, in a text field (ADR 0014) or off the Posta views.
/// Elsewhere nobody calls it, and nothing comes.
@LazySingleton(as: AppMenu)
class ChannelAppMenu() implements AppMenu {
  /// The runner's channel: `refresh`.
  static const channel = MethodChannel('it.postino/menu');

  late final StreamController<void> _refresh = StreamController<void>.broadcast(
    onListen: () => channel.setMethodCallHandler((call) async {
      if (call.method == 'refresh' && call.arguments != true) _refresh.add(null);
    }),
    onCancel: () => channel.setMethodCallHandler(null),
  );

  @override
  Stream<void> get refresh => _refresh.stream;
}
