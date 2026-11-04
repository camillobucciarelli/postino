import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/encrypted_error_log.dart';
import 'package:postino/core/data/error_log/log_keys.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

void main() {
  final keys = logKeysFrom('ab' * 32);
  late MemoryFileSystem fs;
  late Directory dir;
  final clock = FakeClock(DateTime.utc(2026, 11, 4, 9));

  EncryptedErrorLog log({int cap = 64 * 1024}) => EncryptedErrorLog(dir, keys, clock, cap: cap);

  /// Everything on disk, as text.
  String disk() => [for (final f in dir.listSync().whereType<File>()) f.readAsStringSync()].join();

  setUp(() {
    fs = MemoryFileSystem();
    dir = fs.directory('/support/logs');
  });

  test('an entry reads back decrypted, with time, context and stack; on disk it is not in clear', () async {
    log().record(StateError('Oggetto «Fattura» rifiutato'), stack: StackTrace.fromString('#0 main'), context: 'sync a');

    final text = await log().read();
    expect(text, contains('2026-11-04T09:00:00.000Z'));
    expect(text, contains('[sync a]'));
    expect(text, contains('Oggetto «Fattura» rifiutato'));
    expect(text, contains('#0 main'));
    // Deterministic: «, spaces and # are never in base64, so any of these on disk means plain text.
    expect(disk(), isNot(contains('«Fattura»')));
    expect(disk(), isNot(contains('sync a')));
    expect(disk(), isNot(contains('#0 main')));
    expect(disk(), matches(RegExp(r'^[A-Za-z0-9+/=\n]+$')));
  });

  test('an UnexpectedFailure brings its own stack', () async {
    log().record(UnexpectedFailure('boom', StackTrace.fromString('#0 gmail_http')));
    expect(await log().read(), contains('#0 gmail_http'));
  });

  test('with another key nothing reads, and nothing throws', () async {
    log().record('segreto di prova');
    expect(await EncryptedErrorLog(dir, logKeysFrom('cd' * 32), clock).read(), isEmpty);
  });

  test('a damaged line is skipped, the others still read', () async {
    final l = log()..record('prima');
    dir.childFile('postino.log').writeAsStringSync('\nrotto', mode: FileMode.append);
    l.record('dopo');
    final text = await l.read();
    expect(text, contains('prima'));
    expect(text, contains('dopo'));
  });

  test('a write cut by a crash loses only itself: the next entry still reads', () async {
    final l = log()..record('prima');
    // A write cut after its newline and half its line.
    dir.childFile('postino.log').writeAsStringSync('\nQUJDREVGR0hJSktM', mode: FileMode.append);
    l.record('dopo');
    final text = await l.read();
    expect(text, contains('prima'));
    expect(text, contains('dopo'));
  });

  test('tokens and passwords are redacted before they reach the disk', () async {
    log().record('refresh failed: {"refresh_token": "1//0gSegreto"} Authorization: Bearer ya29.Segreto');
    final text = await log().read();
    expect(text, isNot(contains('Segreto')));
    expect(text, contains('[redatto]'));
  });

  test('past the cap the log rotates: two files at most, the newest entries kept', () async {
    final l = log(cap: 2048);
    for (var i = 0; i < 100; i++) {
      l.record('voce $i ${'x' * 50}');
    }
    expect(dir.listSync().whereType<File>().length, lessThanOrEqualTo(2));
    for (final f in dir.listSync().whereType<File>()) {
      expect(f.lengthSync(), lessThan(2048 + 512));
    }
    final text = await l.read();
    expect(text, contains('voce 99 '));
    expect(text, isNot(contains('voce 0 ')));
    // Oldest first.
    expect(text.indexOf('voce 98 '), lessThan(text.indexOf('voce 99 ')));
  });

  test('one huge entry is cut, not written whole', () async {
    final l = log()..record('y' * 100000);
    expect(dir.childFile('postino.log').lengthSync(), lessThan(16 * 1024));
    expect(await l.read(), contains('[troncato]'));
  });

  test('clearing removes every entry and the crash mark', () async {
    final l = log()
      ..record('vecchia', crash: true)
      ..record('altra');
    await l.clear();
    expect(await l.read(), isEmpty);
    expect(await l.takeCrashMark(), isFalse);
  });

  test('an uncaught error leaves the crash mark, taken once; a recorded Failure does not', () async {
    log().record(const OfflineFailure());
    expect(await log().takeCrashMark(), isFalse);

    log().record(StateError('crash'), crash: true);
    final restarted = log();
    expect(await restarted.takeCrashMark(), isTrue);
    expect(await restarted.takeCrashMark(), isFalse);
    expect(await restarted.read(), contains('crash'));
  });

  test('the same crash rethrown up to the uncaught handler is written once; a repeated Failure every time', () async {
    final error = StateError('database');
    final l = log()
      ..record(error, context: 'database', crash: true)
      ..record(error, context: 'uncaught', crash: true)
      ..record(const OfflineFailure())
      ..record(const OfflineFailure());
    final text = await l.read();
    expect('[database]'.allMatches(text), hasLength(1));
    expect(text, isNot(contains('[uncaught]')));
    expect('OfflineFailure'.allMatches(text), hasLength(2));
  });

  test('a disk that fails never throws from record', () {
    final failing = MemoryFileSystem(opHandle: (_, op) => throw const FileSystemException('disco pieno'));
    expect(() => EncryptedErrorLog(failing.directory('/logs'), keys, clock).record('x', crash: true), returnsNormally);
  });
}
