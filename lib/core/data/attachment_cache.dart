import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pointycastle/export.dart';

import '../domain/attachment_repository.dart';
import '../domain/file_name.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'sync_engine.dart';

/// Where attachments live: [cache] holds them encrypted, [temp] their decrypted copies for other apps.
/// [cap] bounds the cache in bytes (500 MB; smaller only in tests).
class AttachmentStorage {
  AttachmentStorage._(this.cache, this.temp, this.cap);

  /// A staging file this old is left from a crash, never a write in progress.
  static const stalePart = Duration(hours: 1);

  final Directory cache;
  final Directory temp;
  final int cap;

  /// Clears what [stalePart] has left: decrypted copies in [temp] and half-written cache files older than
  /// that. A younger one may be a copy another app has just opened, or the write of another isolate (#36).
  static Future<AttachmentStorage> open(
    Directory cache,
    Directory temp, {
    int cap = 500 * 1024 * 1024,
  }) async {
    await temp.create(recursive: true);
    await cache.create(recursive: true);
    final before = DateTime.now().subtract(stalePart);
    await for (final e in temp.list()) {
      if ((await e.stat()).modified.isBefore(before)) {
        await e.delete(recursive: true);
      }
    }
    await for (final e in cache.list()) {
      if (e.basename.endsWith('.part') &&
          (await e.stat()).modified.isBefore(before)) {
        await e.delete();
      }
    }
    return AttachmentStorage._(cache, temp, cap);
  }
}

/// The attachment cache (#34): each file encrypted at rest (AES-256-CTR, then HMAC-SHA256 over IV and
/// ciphertext) with a key kept in the keychain, evicted least recently used beyond [AttachmentStorage.cap].
/// Last use is the file's modification time, so the cache needs no table of its own.
@LazySingleton(as: AttachmentRepository)
class AttachmentCache implements AttachmentRepository {
  AttachmentCache(this._sync, this._keychain, this._clock, this._storage);

  final SyncEngine _sync;
  final SecureStore _keychain;
  final Clock _clock;
  final AttachmentStorage _storage;

  static const _keyName = 'attachments_key';
  static const _ivLength = 16, _macLength = 32;

  /// What encryption adds to a file.
  static const overhead = _ivLength + _macLength;

  /// Loaded once; a keychain error is not remembered, so the next try asks again.
  Future<_Keys>? _keys;

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
      return await _file(
        accountId,
        messageId,
        attachment,
        onProgress,
        cancel,
        () => cancelled,
      );
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
    if (await cached.exists()) {
      plain = await _crypt(_decrypt, await cached.readAsBytes(), keys);
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
        final sealed = (await _crypt(_encrypt, plain, keys))!;
        if (cancelled()) return const Err(CancelledFailure());
        // Written aside then renamed: a crash never leaves half a file under the real name.
        // A name of its own per write: two downloads of the same attachment never share a staging file.
        final part = _storage.cache.childFile(
          '${cached.basename}.${_hex(_random(4))}.part',
        );
        try {
          await part.writeAsBytes(sealed, flush: true);
          if (cancelled()) return const Err(CancelledFailure());
          await part.rename(cached.path);
          stored = true;
        } finally {
          if (await part.exists()) await part.delete();
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
            if (await cached.exists()) await cached.delete();
          });
        }
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Left behind: the next launch empties the temporary folder, eviction the cache.
      }
      return const Err(CancelledFailure());
    } catch (_) {
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<Result<Uint8List>> bytes(
    String accountId,
    String messageId,
    String attachmentId,
  ) async {
    try {
      final cached = _cached(accountId, messageId, attachmentId);
      if (await cached.exists()) {
        final keys = await (_keys ??= _loadKeys());
        final plain = await _crypt(_decrypt, await cached.readAsBytes(), keys);
        if (plain != null) return Ok(plain);
      }
    } on Exception catch (e) {
      // Unreadable cache or keychain: the Provider still has it.
      debugPrint('[attachments] cache read failed, $e');
    }
    return _sync.fetchAttachment(accountId, messageId, attachmentId);
  }

  File _cached(String accountId, String messageId, String attachmentId) =>
      _storage.cache.childFile(
        sha256
            .convert(utf8.encode('$accountId\n$messageId\n$attachmentId'))
            .toString(),
      );

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
        if (e is File && !e.basename.endsWith('.part')) (e, await e.stat()),
    ]..sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var total = files.fold(0, (sum, f) => sum + f.$2.size);
    for (final (f, stat) in files) {
      if (total <= _storage.cap) break;
      // Gone already (a read found it damaged): nothing to free.
      if (await f.exists()) await f.delete();
      total -= stat.size;
    }
  }

  Future<_Keys> _loadKeys() async {
    final String hex;
    try {
      hex = await _readOrCreateKey();
    } catch (_) {
      _keys = null;
      rethrow;
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    return (enc: bytes.sublist(0, 32), mac: bytes.sublist(32));
  }

  Future<String> _readOrCreateKey() async {
    var hex = await _keychain.read(_keyName);
    if (hex == null) {
      hex = _hex(_random(64));
      await _keychain.write(_keyName, hex);
    }
    return hex;
  }

  /// In a background isolate past 1 MB: pure Dart AES would stall the UI.
  static Future<Uint8List?> _crypt(
    Uint8List? Function(Uint8List, _Keys) op,
    Uint8List data,
    _Keys keys,
  ) async => data.length > 1 << 20
      ? Isolate.run(() => op(data, keys))
      : op(data, keys);

  static Uint8List? _encrypt(Uint8List plain, _Keys keys) {
    final iv = _random(_ivLength);
    final out = BytesBuilder(copy: false)
      ..add(iv)
      ..add(_ctr(keys.enc, iv, plain));
    final sealed = out.takeBytes();
    return (BytesBuilder(copy: false)
          ..add(sealed)
          ..add(Hmac(sha256, keys.mac).convert(sealed).bytes))
        .takeBytes();
  }

  /// Null when the MAC does not match.
  static Uint8List? _decrypt(Uint8List sealed, _Keys keys) {
    if (sealed.length < overhead) return null;
    final body = Uint8List.sublistView(sealed, 0, sealed.length - _macLength);
    final mac = Hmac(sha256, keys.mac).convert(body).bytes;
    final tag = Uint8List.sublistView(sealed, sealed.length - _macLength);
    // Constant time.
    var diff = 0;
    for (var i = 0; i < _macLength; i++) {
      diff |= mac[i] ^ tag[i];
    }
    if (diff != 0) return null;
    return _ctr(
      keys.enc,
      Uint8List.sublistView(body, 0, _ivLength),
      Uint8List.sublistView(body, _ivLength),
    );
  }

  static Uint8List _ctr(Uint8List key, Uint8List iv, Uint8List data) =>
      (CTRStreamCipher(
        AESEngine(),
      )..init(true, ParametersWithIV(KeyParameter(key), iv))).process(data);

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
  }
}

String _hex(List<int> bytes) =>
    [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

typedef _Keys = ({Uint8List enc, Uint8List mac});
