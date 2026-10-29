/// What the UI may ask of the sync engine: it still reads only from the database (ADR 0003).
abstract interface class MailSync {
  /// Syncs every attivo Account now (pull-to-refresh); completes when done.
  Future<void> syncAll();
}
