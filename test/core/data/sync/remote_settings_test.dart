// What the copies of the file on Drive are for a device and its key (ADR 0019): the states of the table.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/remote_settings.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_settings_backend.dart';

Map<String, Object?> _voce(int at) => {
  'value': {'at': at},
  'updatedAt': at,
  'deviceId': 'Z',
  'deleted': false,
};

String _doc(Map<String, Object?> entries, {int schema = 3}) =>
    jsonEncode({'schemaVersion': schema, 'entries': entries});

String _sealed(Map<String, Object?> entries, {int schema = 3, SyncKey? key}) =>
    sealedWith({'schemaVersion': schema, 'entries': entries}, key);

Matcher _readable(List<String> keys, {required bool opened, bool duplicates = false}) => isA<ReadableRemote>()
    .having((r) => r.doc.entries.keys.toSet(), 'keys', keys.toSet())
    .having((r) => r.opened, 'opened', opened)
    .having((r) => r.duplicates, 'duplicates', duplicates);

void main() {
  final key = testSyncKey;

  test('no copy is no file', () {
    expect(readRemoteSettings([], key), isA<NoRemoteFile>());
  });

  test('sealed with the key: opened', () {
    expect(
      readRemoteSettings([
        _sealed({'a/1': _voce(1)}),
      ], key),
      _readable(['a/1'], opened: true),
    );
  });

  test('sealed with another key, or none held: locked', () {
    final sealed = _sealed({'a/1': _voce(1)});
    expect(readRemoteSettings([sealed], SyncKey.random()), isA<LockedRemote>());
    expect(readRemoteSettings([sealed], null), isA<LockedRemote>());
  });

  test('sealed, but no settings document inside: unreadable', () {
    expect(
      readRemoteSettings([
        sealedWith({'nope': 1}),
      ], key),
      isA<UnreadableRemote>(),
    );
  });

  test('a newer envelope is unreadable and says so', () {
    final newer = _sealed({}).replaceFirst('"postinoEncrypted":1', '"postinoEncrypted":2');
    expect(readRemoteSettings([newer], key), isA<UnreadableRemote>().having((r) => r.newer, 'newer', isTrue));
    expect(
      readRemoteSettings(['{"postinoEncrypted":1}'], key),
      isA<UnreadableRemote>().having((r) => r.newer, 'newer', isFalse),
    );
  });

  group('in clear', () {
    test('without a key: read up to schema 2, never its credentials/ voci', () {
      for (final schema in [1, 2]) {
        expect(
          readRemoteSettings([
            _doc({'a/1': _voce(1), 'credentials/x': _voce(1), 'credentials/x/c': _voce(1)}, schema: schema),
          ], null),
          _readable(['a/1'], opened: false),
        );
      }
    });

    test('without a key, above schema 2 or not a document: unreadable', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}),
        ], null),
        isA<UnreadableRemote>().having((r) => r.newer, 'newer', isFalse),
      );
      expect(readRemoteSettings(['{"x":1}'], null), isA<UnreadableRemote>().having((r) => r.newer, 'newer', isFalse));
    });

    test('with a key: nothing taken, to be overwritten', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}, schema: 2),
        ], key),
        _readable([], opened: false),
      );
    });
  });

  group('duplicates', () {
    test('those that open are merged into the oldest, last write wins', () {
      final r = readRemoteSettings([
        _sealed({'a/1': _voce(5), 'a/2': _voce(1)}),
        _sealed({'a/1': _voce(3), 'a/3': _voce(2)}),
      ], key);
      expect(r, _readable(['a/1', 'a/2', 'a/3'], opened: true, duplicates: true));
      expect((r as ReadableRemote).doc.entries['a/1']?.updatedAt, 5);
    });

    test('those sealed with another key are to drop, those in clear on a device with a key too', () {
      expect(
        readRemoteSettings([
          _sealed({'a/1': _voce(1)}),
          _sealed({'a/2': _voce(1)}, key: SyncKey.random()),
          _doc({'a/3': _voce(1)}, schema: 2),
        ], key),
        _readable(['a/1'], opened: true, duplicates: true),
      );
    });

    test('one that cannot be read, or from a newer schema, leaves all alone: the oldest as it is', () {
      for (final bad in [
        'nope',
        _sealed({'a/2': _voce(1)}, schema: 9),
      ]) {
        expect(
          readRemoteSettings([
            _sealed({'a/1': _voce(1)}),
            bad,
          ], key),
          _readable(['a/1'], opened: true),
        );
      }
    });

    test('the oldest decides: locked, unreadable or from a newer schema, the others are not looked at', () {
      final mine = _sealed({'a/2': _voce(1)});
      expect(readRemoteSettings([_sealed({}, key: SyncKey.random()), mine], key), isA<LockedRemote>());
      expect(readRemoteSettings(['nope', mine], key), isA<UnreadableRemote>());
      final newer = readRemoteSettings([
        _sealed({'a/1': _voce(1)}, schema: 9),
        mine,
      ], key);
      expect(newer, _readable(['a/1'], opened: true));
      expect((newer as ReadableRemote).doc.writable, isFalse);
    });

    test('without a key, a sealed duplicate locks the file: no key of our own over another device\'s', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}, schema: 2),
          _sealed({'a/2': _voce(1)}),
        ], null),
        isA<LockedRemote>(),
      );
    });

    test('without a key, a sealed copy anywhere locks it, even behind one that cannot be read', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}, schema: 2),
          'nope',
          _sealed({}),
        ], null),
        isA<LockedRemote>(),
      );
    });

    test('a copy in clear first and one sealed with the key: opened by that copy', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}, schema: 2),
          _sealed({'a/2': _voce(1)}),
        ], key),
        _readable(['a/2'], opened: true, duplicates: true),
      );
    });

    test('without a key, plain duplicates up to schema 2 merge as the first migration', () {
      expect(
        readRemoteSettings([
          _doc({'a/1': _voce(1)}, schema: 2),
          _doc({'a/2': _voce(1)}, schema: 1),
        ], null),
        _readable(['a/1', 'a/2'], opened: false, duplicates: true),
      );
    });
  });

  test('a failure never carries the key', () {
    final r = readRemoteSettings([
      '{"postinoEncrypted":1,"keyId":"${key.id}","nonce":"AAAAAAAAAAAAAAAA","ciphertext":"AAAA"}',
    ], key);
    expect(r, isA<UnreadableRemote>().having((u) => '${u.failure}', 'failure', isNot(contains(key.encode()))));
    expect(r, isA<UnreadableRemote>().having((u) => u.failure, 'failure', isA<UnexpectedFailure>()));
  });
}
