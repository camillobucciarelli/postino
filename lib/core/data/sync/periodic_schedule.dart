import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/platform_services.dart';
import '../mail_store.dart';

/// Keeps the [PeriodicSync] (#212) in step with the Accounts: scheduled while there is at least one, at every app
/// start too (the platform keeps one), cancelled once the last is removed (#174).
@lazySingleton
class PeriodicSchedule(final MailStore _store, final PeriodicSync _periodic) {
  StreamSubscription<bool>? _sub;

  void start() => _sub ??= _store.watchAccounts().map((a) => a.isNotEmpty).distinct().listen((any) async {
    try {
      await (any ? _periodic.schedule() : _periodic.cancel());
    } on Object catch (e) {
      debugPrint('[background] periodic sync: ${e.runtimeType}');
    }
  });

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
