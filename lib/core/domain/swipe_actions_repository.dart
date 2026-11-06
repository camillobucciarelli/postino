import 'swipe_actions.dart';

/// The Azioni of the swipes: an Impostazione di Postino, the same for every Account (ADR 0016).
abstract interface class SwipeActionsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The Azione of each direction, now and after each change; [swipeActionsDefault] until chosen.
  Stream<SwipeActions> watch();

  /// Sets the Azione of [direction].
  Future<void> set(SwipeDirection direction, SwipeAction action);
}
