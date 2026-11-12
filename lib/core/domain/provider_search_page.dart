import 'package:equatable/equatable.dart';

import 'message.dart';

/// A page of a search on the Provider (#207): what `MailProvider.search` found, newest first.
class const ProviderSearchPage({
  /// The messages found that are not stored here yet: headers with Etichette and Conversazione, as the sync gives them.
  final List<Message> messages = const [],

  /// The Conversazioni of every message found on this page, those already stored here too.
  final Set<String> conversationIds = const {},

  /// Opaque to the core: the next page, null on the last one.
  final String? nextPageToken,
}) extends Equatable {
  /// Crea una pagina; senza argomenti è vuota e l'ultima.
  this;

  @override
  List<Object?> get props => [messages, conversationIds, nextPageToken];
}
