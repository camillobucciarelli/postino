import 'draft_content.dart';

/// What the Provider answers to a Bozza upload (`MailProvider.saveDraft`, #149).
sealed class const DraftOutcome() {
  /// Costruttore delle varianti.
  this;
}

/// Salvata: the Bozza is new, or the Provider had the expected version, or already the wanted one.
final class const DraftSaved() extends DraftOutcome {
  /// Crea l'esito.
  this;
}

/// Changed elsewhere to [provider], neither the expected nor the wanted version: nothing was written.
final class const DraftDiverged(
  /// What the Provider has now.
  final DraftContent provider,
) extends DraftOutcome {
  /// Crea l'esito.
  this;
}
