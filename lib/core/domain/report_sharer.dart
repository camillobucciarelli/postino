/// The system share sheet, for a Segnalazione di un problema without an Account (#117); the real one in core/data.
abstract interface class ReportSharer() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Shares [text] as a text file called [name], with [subject] where the target takes one. The file is temporary:
  /// it is deleted at the next start.
  Future<void> share({required String text, required String name, required String subject});
}
