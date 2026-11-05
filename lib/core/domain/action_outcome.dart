/// What the Provider answers to a conditional Azione (`MailProvider.applyAction`, ADR 0008).
sealed class const ActionOutcome() {
  /// Costruttore delle varianti.
  this;
}

/// Applicata: the Provider had the expected value, or already the wanted one.
final class const ActionApplied() extends ActionOutcome {
  /// Crea l'esito.
  this;
}

/// Conflitto: the attribute was changed elsewhere to [providerValue]; nothing was written.
final class const ActionConflict(
  /// The value the Provider has: a `bool`, or a `Placement`.
  final Object providerValue,
) extends ActionOutcome {
  /// Crea l'esito.
  this;
}

/// Messaggio sparito: it no longer exists on the Provider.
final class const ActionMessageGone() extends ActionOutcome {
  /// Crea l'esito.
  this;
}
