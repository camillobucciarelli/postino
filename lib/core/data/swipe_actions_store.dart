import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../domain/platform_services.dart';
import '../domain/swipe_actions.dart';
import '../domain/swipe_actions_repository.dart';
import 'postino_database.dart';

/// The voci `swipe/left` and `swipe/right` of the Impostazioni di Postino (ADR 0016): each holds the name of the
/// Azione as a JSON string. A missing, removed or unknown value reads as the default.
@LazySingleton(as: SwipeActionsRepository)
class SwipeActionsStore(final PostinoDatabase _db, final Clock _clock) implements SwipeActionsRepository {
  static String _key(SwipeDirection d) => 'swipe/${d.name}';

  @override
  Stream<SwipeActions> watch() => _db.postinoSettingsDao.watchPrefix('swipe/').map((rows) {
    SwipeAction of(SwipeDirection d, SwipeAction fallback) {
      final raw = rows.where((r) => r.key == _key(d)).firstOrNull?.value;
      final name = raw == null ? null : _decode(raw);
      return SwipeAction.values.where((a) => a.name == name).firstOrNull ?? fallback;
    }

    return (
      left: of(SwipeDirection.left, swipeActionsDefault.left),
      right: of(SwipeDirection.right, swipeActionsDefault.right),
    );
  });

  @override
  Future<void> set(SwipeDirection direction, SwipeAction action) =>
      _db.postinoSettingsDao.write(_key(direction), jsonEncode(action.name), at: _clock.now());

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
