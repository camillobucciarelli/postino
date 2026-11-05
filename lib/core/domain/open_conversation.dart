import 'package:injectable/injectable.dart';

import 'mail_notification.dart';

/// The Conversazione on screen (#39): its new messages are not notified.
@lazySingleton
class OpenConversation() {
  /// Nessuna Conversazione sullo schermo all'inizio.
  this;

  ConversationKey? _current;

  /// The Conversazione [key] is now on screen.
  void show(ConversationKey key) => _current = key;

  /// [key] left the screen; nothing if another one has replaced it meanwhile (the fade between two).
  void hide(ConversationKey key) {
    if (_current == key) _current = null;
  }

  /// Whether [key] is the Conversazione on screen.
  bool isOpen(ConversationKey key) => _current == key;
}
