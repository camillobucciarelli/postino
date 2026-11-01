import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:injectable/injectable.dart';
import 'package:pointycastle/export.dart';

import '../domain/attachment_repository.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'sync_engine.dart';

/// Where attachments live: [cache] holds them encrypted, [temp] their decrypted copies for other apps.
/// [cap] bounds the cache in bytes (500 MB; smaller only in tests).
class AttachmentStorage {
  AttachmentStorage._(this.cache, this.temp, this.cap);

  final Directory cache;
  final Directory temp;
  final int cap;

  /// Empties [temp]: the decrypted copies of the previous launch go.
  static Future<AttachmentStorage> open(
    Directory cache,
    Directory temp, {
    int cap = 500 * 1024 * 1024,
  }) async {
    if (await temp.exists()) await temp.delete(recursive: true);
    await temp.create(recursive: true);
    await cache.create(recursive: true);
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

  late final Future<_Keys> _keys = _loadKeys();

  @override
  Future<Result<String>> file(
    String accountId,
    String messageId,
    Attachment attachment, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final keys = await _keys;
    final cached = _storage.cache.childFile(
      sha256
          .convert(utf8.encode('$accountId\n$messageId\n${attachment.id}'))
          .toString(),
    );
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
      // Bigger than the whole cache: opened from the temporary copy only.
      if (plain.length + overhead <= _storage.cap) {
        final sealed = (await _crypt(_encrypt, plain, keys))!;
        // Written aside then renamed: a crash never leaves half a file under the real name.
        final part = _storage.cache.childFile('${cached.basename}.part');
        await part.writeAsBytes(sealed, flush: true);
        await part.rename(cached.path);
        await cached.setLastModified(_clock.now());
        await _evict();
      }
    }
    // One folder per copy, so the file keeps its own name and two of the same name do not clash.
    final dir = await _storage.temp.createTemp();
    final copy = dir.childFile(safeFileName(attachment.name));
    await copy.writeAsBytes(plain, flush: true);
    return Ok(copy.path);
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
      await f.delete();
      total -= stat.size;
    }
  }

  Future<_Keys> _loadKeys() async {
    var hex = await _keychain.read(_keyName);
    if (hex == null) {
      final random = Random.secure();
      hex = [
        for (var i = 0; i < 64; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();
      await _keychain.write(_keyName, hex);
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    return (enc: bytes.sublist(0, 32), mac: bytes.sublist(32));
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

typedef _Keys = ({Uint8List enc, Uint8List mac});

/// [name] as a file name: no folders (a hostile `../../x` stays inside the temporary folder), never empty.
String safeFileName(String name) {
  final s = name.replaceAll(RegExp(r'[/\\:\x00-\x1f]'), '_').trim();
  return s.isEmpty || s == '.' || s == '..' ? 'allegato' : s;
}
