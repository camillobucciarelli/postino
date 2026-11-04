import 'dart:typed_data';

import 'message.dart';
import 'result.dart';

/// Attachments of a Conversazione: downloaded once into an encrypted cache, opened from there, offline too.
abstract interface class AttachmentRepository {
  /// The path of a decrypted copy of [attachment] in the app's temporary folder, gone at the next launch;
  /// downloaded from the Provider first unless cached. [onProgress] and [cancel] as in the Provider's download.
  Future<Result<String>> file(
    String accountId,
    String messageId,
    Attachment attachment, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  });

  /// The bytes of attachment [attachmentId] for a forward (#36): from the cache when there (offline too),
  /// else downloaded from the Provider, not stored.
  Future<Result<Uint8List>> bytes(String accountId, String messageId, String attachmentId);
}
