import 'dart:convert';

import 'package:file/file.dart';

import '../../domain/error_log.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../attachment_crypto.dart';
import 'log_redaction.dart';

/// Longest entry kept, in characters, after redaction: a giant stack is cut.
const _maxEntry = 8 * 1024;

/// The error log on disk (#116): one line per entry in [_dir], each sealed on its own with the attachment cache's
/// format (AES-256-CTR + HMAC-SHA256, see attachment_crypto.dart) and written synchronously, so an entry written
/// just before a crash is there; a line cut by one is skipped on reading, and the next entry still reads.
/// Rotates past [_cap] bytes: the current file becomes the previous one, which is dropped; two files at most.
// ponytail: two isolates (app and WorkManager) may rotate at once and lose a file; a lock if that ever matters.
class EncryptedErrorLog(
  final Directory _dir,
  final AttachmentKeys _keys,
  final Clock _clock, {
  final int _cap = 256 * 1024,
}) implements ErrorLog {
  File get _current => _dir.childFile('postino.log');
  File get _previous => _dir.childFile('postino.log.1');
  File get _crashMark => _dir.childFile('crashed');

  @override
  void record(Object error, {StackTrace? stack, String? context, bool crash = false}) {
    try {
      if (crash) _crashMark.createSync(recursive: true);
      final trace = stack ?? (error is UnexpectedFailure ? error.stackTrace : null);
      final head = '${_clock.now().toUtc().toIso8601String()}${context == null ? '' : ' [$context]'} $error';
      // Redacted before the cut, so the cut cannot split a secret past the patterns.
      var entry = redactSecrets(trace == null ? head : '$head\n${'$trace'.trimRight()}');
      if (entry.length > _maxEntry) entry = '${entry.substring(0, _maxEntry)}\n[troncato]';
      // The newline goes first: after a write cut by a crash, the next entry starts on a line of its own.
      final line = '\n${base64.encode(encryptAttachment(utf8.encode(entry), _keys))}';
      _dir.createSync(recursive: true);
      if (_current.existsSync() && _current.lengthSync() + line.length > _cap) {
        _current.renameSync(_previous.path);
      }
      _current.writeAsStringSync(line, mode: FileMode.append, flush: true);
      // The log must never be the cause of a second error: a full or read-only disk loses the entry.
    } on Object catch (_) {}
  }

  @override
  Future<String> read() async {
    final entries = <String>[];
    for (final file in [_previous, _current]) {
      if (!file.existsSync()) continue;
      for (final line in file.readAsLinesSync()) {
        try {
          if (decryptAttachment(base64.decode(line), _keys) case final plain?) entries.add(utf8.decode(plain));
          // A line cut by a crash, an empty one, or not base64: skipped.
        } on FormatException catch (_) {}
      }
    }
    return entries.join('\n\n');
  }

  @override
  Future<void> clear() async {
    for (final file in [_current, _previous, _crashMark]) {
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<bool> takeCrashMark() async {
    if (!_crashMark.existsSync()) return false;
    _crashMark.deleteSync();
    return true;
  }
}
