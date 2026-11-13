import 'dart:async';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../domain/app_menu.dart';

/// macOS (`macos/Runner/MailMenu.swift`): the runner calls `refresh` on [channel] when «Aggiorna» is chosen.
/// Elsewhere nobody calls it, and nothing comes.
@LazySingleton(as: AppMenu)
class ChannelAppMenu() implements AppMenu {
  /// The runner's channel: `refresh`.
  static const channel = MethodChannel('it.postino/menu');

  late final StreamController<void> _refresh = StreamController<void>.broadcast(
    onListen: () => channel.setMethodCallHandler((call) async {
      if (call.method == 'refresh') _refresh.add(null);
    }),
    onCancel: () => channel.setMethodCallHandler(null),
  );

  @override
  Stream<void> get refresh => _refresh.stream;
}
