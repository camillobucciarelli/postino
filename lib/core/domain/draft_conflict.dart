import 'package:equatable/equatable.dart';

import 'draft_content.dart';

/// A Bozza edited here and elsewhere since its last upload (#149): it stays open, the Composizione keeping [mine],
/// until the user keeps it («La tua»: the Provider is updated) or [provider] («Del Provider»: the Bozza here takes it).
class const DraftConflict({
  /// L'Account della Bozza.
  required final String accountId,

  /// RFC 5322 Message-ID of the Bozza.
  required final String messageId,

  /// The version here.
  required final DraftContent mine,

  /// The version on the Provider.
  required final DraftContent provider,
}) extends Equatable {
  /// Crea un Conflitto della Bozza.
  this;

  @override
  List<Object?> get props => [accountId, messageId, mine, provider];
}
