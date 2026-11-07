import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/attachment_repository.dart';
import '../domain/file_name.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'attachment_crypto.dart';

/// Where attachments live: [cache] holds them encrypted, [temp] their decrypted copies for other apps.
/// [cap] bounds the cache in bytes (500 MB; smaller only in tests).
class AttachmentStorage._(final Directory cache, final Directory temp, final int cap) {
  /// A staging file this old is left from a crash, never a write in progress.
  static const stalePart = Duration(hours: 1);

  /// Clears what [stalePart] has left: decrypted copies in [temp] and half-written cache files older than
  /// that. A younger one may be a copy another app has just opened, or the write of another isolate (#36).
  static Future<AttachmentStorage> open(Directory cache, Directory temp, {int cap = 500 * 1024 * 1024}) async {
    await temp.create(recursive: true);
    await cache.create(recursive: true);
    final before = DateTime.now().subtract(stalePart);
    await for (final e in temp.list()) {
      if (e.statSync().modified.isBefore(before)) {
        await e.delete(recursive: true);
      }
    }
    await for (final e in cache.list()) {
      if (e.basename.endsWith('.part') && e.statSync().modified.isBefore(before)) {
        await e.delete();
      }
    }
    return AttachmentStorage._(cache, temp, cap);
  }
}

/// The attachment cache (#34): each file encrypted at rest (attachment_crypto.dart) with a key kept in the
/// keychain, evicted least recently used beyond [AttachmentStorage.cap].
/// Last use is the file's modification time, so the cache needs no table of its own.
@LazySingleton(as: AttachmentRepository)
class AttachmentCache(
  final MailSync _sync,
  final SecureStore _keychain,
  final Clock _clock,
  final AttachmentStorage _storage,
) implements AttachmentRepository {
  static const _keyName = 'attachments_key';

  /// What encryption adds to a file.
  static const overhead = attachmentOverhead;

  /// Loaded once; a keychain error is not remembered, so the next try asks again.
  Future<AttachmentKeys>? _keys;

  /// Never throws: a file system or keychain error is an [UnexpectedFailure].
  @override
  Future<Result<String>> file(
    String accountId,
    String messageId,
    Attachment attachment, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    var cancelled = false;
    unawaited(cancel?.then((_) => cancelled = true));
    try {
      return await _file(accountId, messageId, attachment, onProgress, cancel, () => cancelled);
    } on Exception catch (e, s) {
      return Err(UnexpectedFailure(e, s));
    }
  }

  Future<Result<String>> _file(
    String accountId,
    String messageId,
    Attachment attachment,
    void Function(double done)? onProgress,
    Future<void>? cancel,
    bool Function() cancelled,
  ) async {
    final keys = await (_keys ??= _loadKeys());
    final cached = _cached(accountId, messageId, attachment.id);
    Uint8List? plain;
    if (cached.existsSync()) {
      plain = await _crypt(decryptAttachment, await cached.readAsBytes(), keys);
      if (plain == null) {
        // Damaged (or from another key): downloaded again.
        await cached.delete();
      } else {
        await cached.setLastModified(_clock.now());
      }
    }
    // Set once this call put the attachment in the cache: Annulla pressed later takes it out again.
    var stored = false;
    if (plain == null) {
      final r = await _sync.fetchAttachment(
        accountId,
        messageId,
        attachment.id,
        onProgress: onProgress,
        cancel: cancel,
      );
      switch (r) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          plain = value;
      }
      // Annulla may land after the Provider's last abortable moment, or during encryption and writes:
      // checked after each step, the result is dropped all the same.
      if (cancelled()) return const Err(CancelledFailure());
      // Bigger than the whole cache: opened from the temporary copy only.
      // ponytail: whole attachment in memory (download, base64, encryption): Gmail caps an attachment at 25 MB
      // (a message at 50), so the peak stays around 4x that; stream to disk and encrypt in chunks if a Provider
      // ever serves files of hundreds of MB.
      if (plain.length + overhead <= _storage.cap) {
        final sealed = (await _crypt(encryptAttachment, plain, keys))!;
        if (cancelled()) return const Err(CancelledFailure());
        // Written aside then renamed: a crash never leaves half a file under the real name.
        // A name of its own per write: two downloads of the same attachment never share a staging file.
        final part = _storage.cache.childFile('${cached.basename}.${hex(randomBytes(4))}.part');
        try {
          await part.writeAsBytes(sealed, flush: true);
          if (cancelled()) return const Err(CancelledFailure());
          await part.rename(cached.path);
          stored = true;
        } finally {
          if (part.existsSync()) await part.delete();
        }
        await cached.setLastModified(_clock.now());
        await _serially(_evict);
      }
    }
    // One folder per copy, so the file keeps its own name and two of the same name do not clash.
    final dir = await _storage.temp.createTemp();
    try {
      final copy = dir.childFile(safeFileName(attachment.name));
      if (!cancelled()) await copy.writeAsBytes(plain, flush: true);
      // On macOS the App Sandbox puts com.apple.quarantine (flag 0x0080) on every file the app writes, this copy and the Save As copy included: no xattr call here (a child process is denied). QA: xattr -p com.apple.quarantine on an opened copy (#75).
      if (!cancelled()) return Ok(copy.path);
      // Annulla wins even over a failed cleanup: in the queue, so an eviction never deletes the same file.
      try {
        if (stored) {
          await _serially(() async {
            if (cached.existsSync()) await cached.delete();
          });
        }
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Left behind: the next launch empties the temporary folder, eviction the cache.
      }
      return const Err(CancelledFailure());
    } catch (_) {
      if (dir.existsSync()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<Result<Uint8List>> bytes(String accountId, String messageId, String attachmentId) async {
    try {
      final cached = _cached(accountId, messageId, attachmentId);
      if (cached.existsSync()) {
        final keys = await (_keys ??= _loadKeys());
        final plain = await _crypt(decryptAttachment, await cached.readAsBytes(), keys);
        if (plain != null) return Ok(plain);
      }
    } on Exception catch (e) {
      // Unreadable cache or keychain: the Provider still has it.
      debugPrint('[attachments] cache read failed, $e');
    }
    return _sync.fetchAttachment(accountId, messageId, attachmentId);
  }

  // ponytail: svuota tutta la cache, per-Account se servirà (the file names are hashes: they do not say the Account).
  /// Best effort, never throws: what is left (a copy another app holds open on Windows, a folder that cannot be
  /// listed) goes with the next launch or the eviction.
  @override
  Future<void> clear() => _serially(() async {
    for (final dir in [_storage.cache, _storage.temp]) {
      try {
        await for (final e in dir.list()) {
          try {
            await e.delete(recursive: true);
          } on Object catch (err) {
            debugPrint('[attachments] clear: ${e.basename} left, ${err.runtimeType}');
          }
        }
      } on Object catch (err) {
        debugPrint('[attachments] clear: ${dir.basename} not listed, ${err.runtimeType}');
      }
    }
  });

  File _cached(String accountId, String messageId, String attachmentId) =>
      _storage.cache.childFile(sha256.convert(utf8.encode('$accountId\n$messageId\n$attachmentId')).toString());

  /// Deletions in the cache, one at a time: two at once would pick, and delete, the same file.
  /// A failed one does not block the next.
  Future<void> _deleting = Future.value();

  Future<void> _serially(Future<void> Function() op) {
    final run = _deleting.then((_) => op());
    _deleting = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Drops the least recently used files until the cache fits its cap.
  Future<void> _evict() async {
    final files = [
      for (final e in await _storage.cache.list().toList())
        if (e is File && !e.basename.endsWith('.part')) (e, e.statSync()),
    ]..sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var total = files.fold(0, (sum, f) => sum + f.$2.size);
    for (final (f, stat) in files) {
      if (total <= _storage.cap) break;
      // Gone already (a read found it damaged): nothing to free.
      if (f.existsSync()) await f.delete();
      total -= stat.size;
    }
  }

  Future<AttachmentKeys> _loadKeys() async {
    final String hex;
    try {
      hex = await _readOrCreateKey();
    } catch (_) {
      _keys = null;
      rethrow;
    }
    return attachmentKeysFromHex(hex);
  }

  Future<String> _readOrCreateKey() async {
    var key = await _keychain.read(_keyName);
    if (key == null) {
      key = newAttachmentKeyHex();
      await _keychain.write(_keyName, key);
    }
    return key;
  }

  /// In a background isolate past 1 MB: pure Dart AES would stall the UI.
  static Future<Uint8List?> _crypt(
    Uint8List? Function(Uint8List, AttachmentKeys) op,
    Uint8List data,
    AttachmentKeys keys,
  ) async => data.length > 1 << 20 ? Isolate.run(() => op(data, keys)) : op(data, keys);
}
