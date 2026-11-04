/// A model Postino downloads to the device (ADR 0015): the embedding model today, an LLM tomorrow.
class const ModelDescriptor({
  /// Identifica il modello tra quelli gestiti.
  required final String id,

  /// Da dove si scarica il file.
  required final Uri url,

  /// La dimensione attesa del file, in byte: quella mostrata nella conferma su rete cellulare.
  required final int sizeBytes,

  /// The expected SHA-256 of the file, lowercase hex: a download that does not match is discarded.
  required final String sha256,

  /// Il nome del file sul dispositivo, senza cartella.
  required final String fileName,
}) {
  /// Crea il descrittore.
  this;
}
